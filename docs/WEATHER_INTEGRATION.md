# Real Weather Integration

## Status

V0.3 was implemented and locally verified on 2026-07-16.

## Data flow

```text
Open-Meteo Forecast API
  -> DashboardWeather
  -> WeatherSummary
  -> DashboardRenderer
  -> 600 x 800 grayscale PNG
```

The default location is Chengdu Shuangliu District:

- latitude: `30.58`
- longitude: `103.92`
- time zone: `Asia/Shanghai`

The request reads only `temperature_2m`, `weather_code`, `temperature_2m_max`, and `temperature_2m_min` for one forecast day. It does not use device location services, an account, or an API key.

## CLI

```bash
swift run DashboardCLI render --source mock --weather live --output ./output/dashboard.png
swift run DashboardCLI render --source mock --weather mock --output ./output/dashboard.png
swift run DashboardCLI render --weather live --latitude 30.58 --longitude 103.92
```

`live` is the default weather source. Calendar selection remains independent through `--source mock|calendar`.

## Failure behavior

Every successful live response is atomically cached at:

```text
~/Library/Caches/KindleSmartDashboard/weather.json
```

If the network request or API response fails, the provider uses the last cached weather. If no cache exists, rendering fails before the renderer writes the output, preserving the previous valid PNG.

## Verification

- Swift build passed under Xcode 15.2.
- 26 automated tests passed, including URL construction, decoding, temperature rounding, weather-code mapping, invalid coordinates, and location-scoped cache fallback.
- Live Shuangliu weather rendered successfully into a 600 x 800 grayscale PNG.
- Real Apple Calendar and live weather rendered successfully together through the signed helper app.
- Mock weather rendering remained functional.

## Data source and licence

Weather data is provided by [Open-Meteo](https://open-meteo.com/en/docs) under [CC BY 4.0](https://open-meteo.com/en/license). The project rounds Celsius temperatures to whole numbers and converts WMO weather codes to compact Chinese labels. The rendered footer includes `天气 Open-Meteo` when live data is used.
