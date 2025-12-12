import os
from flask import Flask, request, redirect, url_for, render_template, flash
from dotenv import load_dotenv
from db import fetch_all, fetch_one, execute

load_dotenv()

app = Flask(__name__)
app.secret_key = "dev-secret"  # demo; production'da değişir

@app.get("/")
def index():
    campaign_id = int(request.args.get("campaign_id", "1"))
    q = request.args.get("q", "")

    campaigns = fetch_all("SELECT campaign_id, name FROM campaign ORDER BY campaign_id;")
    classes = fetch_all("SELECT class_id, name FROM rpg_class ORDER BY name;")

    rows = fetch_all(
        "SELECT * FROM fn_search_characters(%s, %s);",
        (campaign_id, q if q else None),
    )

    return render_template(
        "index.html",
        rows=rows,
        campaigns=campaigns,
        classes=classes,
        campaign_id=campaign_id,
        q=q,
    )


@app.post("/transfer")
def transfer_item():
    from_id = int(request.form["from_character_id"])
    to_id = int(request.form["to_character_id"])
    item_id = int(request.form["item_id"])
    qty = int(request.form["qty"])

    execute("CALL sp_transfer_item(%s, %s, %s, %s);", (from_id, to_id, item_id, qty))
    flash("Item transfer edildi.")
    return redirect(url_for("character_detail", character_id=from_id))


@app.post("/characters/<int:character_id>/class")
def change_class(character_id: int):
    new_class_id = int(request.form["class_id"])
    execute("CALL sp_apply_class_to_character(%s, %s);", (character_id, new_class_id))
    flash("Class güncellendi ve modifier'lar uygulandı.")
    return redirect(url_for("character_detail", character_id=character_id))


@app.post("/characters")
def create_character():
    campaign_id = int(request.form["campaign_id"])
    class_id = int(request.form["class_id"])
    name = request.form["name"].strip()
    desc = request.form.get("description", "").strip() or None

    if not name:
        flash("Name boş olamaz.")
        return redirect(url_for("index", campaign_id=campaign_id))

    row = fetch_one(
        "SELECT sp_create_character(%s, %s, %s, %s) AS character_id;",
        (campaign_id, class_id, name, desc),
    )
    flash(f"Karakter oluşturuldu. ID={row['character_id']}")
    return redirect(url_for("character_detail", character_id=row["character_id"]))

@app.get("/characters/<int:character_id>")
def character_detail(character_id: int):
    sheet = fetch_all("SELECT * FROM fn_character_sheet(%s);", (character_id,))
    if not sheet:
        return "Character not found", 404

    head = sheet[0]

    classes = fetch_all("SELECT class_id, name FROM rpg_class ORDER BY name;")
    characters = fetch_all("""
        SELECT ch.character_id, e.name
        FROM character ch
        JOIN entity e ON e.entity_id = ch.entity_id
        ORDER BY ch.character_id;
    """)
    items = fetch_all("""
        SELECT item_id, name
        FROM item
        ORDER BY name;
    """)

    inventory = fetch_all("SELECT * FROM fn_character_inventory(%s);", (character_id,))

    return render_template(
        "character.html",
        head=head,
        sheet=sheet,
        classes=classes,
        characters=characters,
        items=items,
        inventory=inventory
    )

@app.post("/characters/<int:character_id>/level")
def update_level(character_id: int):
    level = int(request.form["level"])
    execute("UPDATE character SET level=%s WHERE character_id=%s;", (level, character_id))
    flash("Level güncellendi.")
    return redirect(url_for("character_detail", character_id=character_id))

@app.post("/characters/<int:character_id>/delete")
def delete_character(character_id: int):
    # CASCADE: character -> entity -> ilişkili veriler temizlenir (FK'lere bağlı)
    execute("DELETE FROM character WHERE character_id=%s;", (character_id,))
    flash("Karakter silindi.")
    return redirect(url_for("index"))

@app.get("/meta")
def meta():
    classes = fetch_all("SELECT class_id, name FROM rpg_class ORDER BY name;")
    campaigns = fetch_all("SELECT campaign_id, name FROM campaign ORDER BY campaign_id;")
    return {"classes": classes, "campaigns": campaigns}

if __name__ == "__main__":
    app.run(debug=True)
