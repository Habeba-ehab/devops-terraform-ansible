
import os
import time

import psycopg2
from flask import Flask, jsonify, request
from psycopg2.extras import RealDictCursor

app = Flask(__name__)

DB_HOST = os.environ["DB_HOST"]
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ["DB_NAME"]
DB_USER = os.environ["DB_USER"]
DB_PASSWORD = os.environ["DB_PASSWORD"]


def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        connect_timeout=5,
        cursor_factory=RealDictCursor,
    )


def initialize_database():
    for attempt in range(10):
        try:
            with get_db_connection() as connection:
                with connection.cursor() as cursor:
                    cursor.execute(
                        """
                        CREATE TABLE IF NOT EXISTS notes (
                            id SERIAL PRIMARY KEY,
                            title TEXT NOT NULL,
                            body TEXT NOT NULL,
                            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                        );
                        """
                    )
            print("Database is ready.")
            return
        except psycopg2.OperationalError:
            if attempt == 9:
                raise
            print("Database not ready yet. Retrying in 3 seconds...")
            time.sleep(3)


@app.get("/health")
def health():
    return jsonify({"status": "ok"}), 200


@app.get("/notes")
def get_notes():
    with get_db_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT id, title, body, created_at FROM notes ORDER BY id;"
            )
            notes = cursor.fetchall()

    return jsonify(notes), 200


@app.post("/notes")
def create_note():
    data = request.get_json(silent=True)

    if not data or not isinstance(data.get("title"), str) or not isinstance(
        data.get("body"), str
    ):
        return jsonify({"error": "Both title and body are required."}), 400

    title = data["title"].strip()
    body = data["body"].strip()

    if not title or not body:
        return jsonify({"error": "Title and body cannot be empty."}), 400

    with get_db_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO notes (title, body)
                VALUES (%s, %s)
                RETURNING id, title, body, created_at;
                """,
                (title, body),
            )
            note = cursor.fetchone()

    return jsonify(note), 201


if __name__ == "__main__":
    initialize_database()
    app.run(host="0.0.0.0", port=8000)
