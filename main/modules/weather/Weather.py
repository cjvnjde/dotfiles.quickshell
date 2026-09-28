#!/usr/bin/env python3
"""Small Open-Meteo client. Location is selected explicitly, never inferred by IP."""
import json
import sys
import urllib.parse
import urllib.request

def fetch(url, params):
    request = urllib.request.Request(url + '?' + urllib.parse.urlencode(params), headers={'User-Agent': 'QuickshellWeather/1.0'})
    with urllib.request.urlopen(request, timeout=12) as response:
        return json.load(response)

try:
    if sys.argv[1] == 'search':
        data = fetch('https://geocoding-api.open-meteo.com/v1/search', {'name': sys.argv[2], 'count': 5, 'language': 'en', 'format': 'json'})
    else:
        lat, lon = float(sys.argv[2]), float(sys.argv[3])
        if not (-90 <= lat <= 90 and -180 <= lon <= 180):
            raise ValueError('Invalid coordinates')
        data = fetch('https://api.open-meteo.com/v1/forecast', {'latitude': lat, 'longitude': lon, 'current': 'temperature_2m,apparent_temperature,relative_humidity_2m,is_day,weather_code,wind_speed_10m', 'daily': 'weather_code,temperature_2m_max,temperature_2m_min', 'timezone': 'auto', 'forecast_days': 4})
    print(json.dumps(data))
except Exception as error:
    print(json.dumps({'error': str(error)}))
    sys.exit(1)
