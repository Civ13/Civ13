# Weather instruments

`code/modules/1713/weather_instruments.dm` gives each age a better way to read
the sky. The better the instrument, the further and surer its forecast. All
readings come from the air grid ([weather-air.md](weather-air.md)), the wind
field ([weather-wind.md](weather-wind.md)), the storms and fronts
([weather-fronts.md](weather-fronts.md)) and the forecast in
`weather_forecast.dm`.

| Instrument | Research | Reads | Forecast |
| --- | --- | --- | --- |
| Rain gauge (bronze, structure) | Bronze Working | water caught since it was emptied, in mm, and whether it was snow | none: a record |
| Weather vane (existing) | Primitive Construction | wind direction and strength in words | a dark sky upwind, no time |
| Thermometer (existing) | Optics & Instruments | air temperature; outdoors also what the wind, damp or sun make it feel like ([feels-like.md](feels-like.md)) | none |
| Barometer (existing) | Optics & Instruments | pressure in hPa and its tendency | 15 minutes ahead, times rounded to five minutes; unsettled weather from a fall below 1000 hPa or 2 hPa |
| Hair hygrometer (item) | Optics & Instruments | relative humidity and dew point; mist or fog about | dew, frost or fog tonight on a clear, still evening or night |
| Cup anemometer (structure) | Steam Power | wind in m/s, km/h and Beaufort force; wind chill | none |
| Weather station (structure) | Electricity | all of the above, and the wind's direction | 30 minutes ahead to the minute, with what will fall (rain, sleet, snow, rain and hail); the nearest low or high and whether it is coming |

## Pressure tendency

`settle_instruments()` runs from the air grid's `settle()`. Every 18 weather
ticks (3 minutes) each cell stores how far its pressure moved since the last
mark. `weather_pressure_tendency_at(A)` blends it like the other readers:
under 0.5 hPa is steady, under 2 slow, under 5 plain, 5 or more fast.

## Rain and the log

Every weather tick (`weather_instruments_step()` from `weather_systems_step()`)
each rain gauge and station out of doors adds 0.5 mm times the storm's
strength while something falls on its tile, up to 200 mm. An empty hand tips
a gauge out. A station writes one log line as each part of the day begins
(temperature, humidity, pressure and tendency, wind, and the rain since the
last line, after which its gauge is emptied) and keeps the last twelve. Gauge
water and logs are not saved, like the air grid.

Art by Fable 5.2: `icons/obj/weather_station.dmi` from
`tests/sprites/create_weather_station.py`. The probe is
`tests/weather_instruments/probe.dm`.
