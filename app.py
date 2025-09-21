from flask import Flask, render_template

app = Flask(__name__)

@app.route("/")
def hello():
    return render_template('index.html')

@app.route("/healthz")
def healthz():
    return render_template('health.html'), 200

if __name__ == "__main__":
    app.run(debug=True)
    