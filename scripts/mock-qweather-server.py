#!/usr/bin/env python3
"""A stand-in for the 和风天气 (QWeather) API, for scripts/ui-tour.sh.

Serves the v1 current, hourly and daily weather and the GeoAPI city lookup for one fixed,
believable day in Hangzhou (UTC+8): 17–24°, feels like 21°, a 55% chance of rain from 14:00
to 18:00, every day. Requests without the header "X-QW-Api-Key: mock-key" get a 401 problem
response, like the real service. Prints "PORT <n>" on its first line, then serves until killed.
"""
import json
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

API_KEY = "mock-key"
LOCAL = timezone(timedelta(hours=8))
RAIN_HOURS = range(14, 18)
RAIN_CHANCE = 0.55
DRY_CHANCE = 0.1
METADATA = {"tag": "mock", "attributions": ["https://developer.qweather.com/attribution.html"]}
HANGZHOU = {
    "name": "杭州", "id": "101210101", "lat": "30.28746", "lon": "120.15358", "adm2": "杭州",
    "adm1": "浙江省", "country": "中国", "tz": "Asia/Shanghai", "utcOffset": "+08:00",
    "isDst": "0", "type": "city", "rank": "11",
}


def iso(moment: datetime) -> str:
    return moment.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%MZ")


def measure(value: float, unit: str = "°C") -> dict:
    return {"value": value, "unit": unit}


def condition(rainy: bool) -> dict:
    return {"text": "小雨", "code": "305"} if rainy else {"text": "多云", "code": "101"}


def current() -> dict:
    return {
        "metadata": METADATA, "condition": condition(False),
        "temperature": measure(19.6), "feelsLike": measure(20.9), "humidity": 0.76,
        "wind": {"direction": {"degree": 90, "compass": "e"}, "speed": measure(3.1, "m/s"), "scale": 3},
        "uvIndex": 2,
    }


def hourly(count: int) -> dict:
    start = datetime.now(LOCAL).replace(minute=0, second=0, microsecond=0)
    hours = []
    for offset in range(count):
        moment = start + timedelta(hours=offset)
        rainy = moment.hour in RAIN_HOURS
        hours.append({
            "forecastTime": iso(moment), "condition": condition(rainy),
            "temperature": measure(21), "feelsLike": measure(21), "humidity": 0.7,
            "wind": {"direction": {"degree": 90, "compass": "e"}, "speed": measure(3, "m/s"), "scale": 2},
            "precipitation": {"probability": RAIN_CHANCE if rainy else DRY_CHANCE, "type": "rain" if rainy else "none"},
            "uvIndex": 3,
        })
    return {"metadata": METADATA, "hours": hours}


def daily(count: int) -> dict:
    midnight = datetime.now(LOCAL).replace(hour=0, minute=0, second=0, microsecond=0)
    days = []
    for offset in range(count):
        start = midnight + timedelta(days=offset)
        days.append({
            "forecastStartTime": iso(start), "forecastEndTime": iso(start + timedelta(days=1)),
            "temperatureMax": measure(24.3), "temperatureMin": measure(16.8), "uvIndexMax": 4,
            "daytime": {"condition": condition(True), "precipitation": {"probability": RAIN_CHANCE, "type": "rain"}},
            "nighttime": {"condition": condition(False)},
        })
    return {"metadata": METADATA, "days": days}


def lookup(query: str) -> dict:
    if "杭" in query or "hangzhou" in query.lower():
        return {"code": "200", "location": [HANGZHOU]}
    return {"code": "404", "location": []}


def problem(status: int, title: str) -> dict:
    return {"error": {"status": status, "type": "https://dev.qweather.com/docs/resource/error-code/",
                      "title": title, "detail": title}}


def count_param(query: dict, name: str, default: int) -> int:
    try:
        return max(1, min(int(query.get(name, [default])[0]), 240))
    except ValueError:
        return default


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.headers.get("X-QW-Api-Key") != API_KEY:
            self.reply(401, problem(401, "Unauthorized"))
            return
        url = urlparse(self.path)
        query = parse_qs(url.query)
        if url.path.startswith("/weather/v1/current/"):
            self.reply(200, current())
        elif url.path.startswith("/weather/v1/hourly/"):
            self.reply(200, hourly(count_param(query, "hours", 24)))
        elif url.path.startswith("/weather/v1/daily/"):
            self.reply(200, daily(count_param(query, "days", 7)))
        elif url.path == "/geo/v2/city/lookup":
            self.reply(200, lookup(query.get("location", [""])[0]))
        else:
            self.reply(404, problem(404, "Not Found"))

    def reply(self, status: int, body: dict) -> None:
        payload = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json" if status == 200 else "application/problem+json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args: object) -> None:
        pass


server = HTTPServer(("127.0.0.1", 0), Handler)
print(f"PORT {server.server_port}", flush=True)
server.serve_forever()
