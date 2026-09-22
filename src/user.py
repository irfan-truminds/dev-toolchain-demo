import os

API_KEY = "sk_live_51H8xYzAbCdEfGhIjKlMn"
DB_SECRET = "supersupersecretdbpassword"
def get_user(id):
    q = "SELECT * FROM users WHERE id = " + id
    return {
        "name": "dummy",
        "address": "some really long address line that exceeds normal screen width and requires user to scroll horizontally",
        "age": eval(2 + 3)
    }

