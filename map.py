import plotly.express as px
import plotly.graph_objects as go
import plotly
import pandas as pd

accesstoken = "pk.eyJ1Ijoiam9oYW5uZ29sdHoiLCJhIjoiY2tjbWFiaHRsMjBzcjJycXFuM3pseDEybSJ9.8MIAWvV1iG11vsGgLpmJsA"

df = pd.read_json("Filialen.json")

px.set_mapbox_access_token(accesstoken)
fig = px.scatter_mapbox(
    df, lat="lat", lon="lon", color="chain", hover_data={"label": True, "hours": True},
    labels={"chain": "Kette"}, title="Lebensmittelläden mit Sonntagsöffung",
    opacity=.8, mapbox_style="light", zoom=5.5, center={"lat": 51.2, "lon": 10.3},
    color_discrete_map={"Schwarzer Netto": "black", "Penny": "#cd1414", "Aldi Nord": "#00b4dc",
                        "Aldi Süd": "#ee6e00", "Lidl": "#003673", "Edeka": "#fce531", "Rewe": "#cc071e"}) #"Roter Netto": "#ffe500",
fig.update_traces({
    "textposition": "bottom center",
    "marker": {"size": 10},
    "hovertemplate": "<b>%{customdata[0]}</b><br><br>%{customdata[1]}<extra></extra>"
})
fig.update_layout(autosize=True, legend=dict(xanchor="left", yanchor="top", y=1, x=0))

fig.show(config={"locale": "de-DE"})
fig.write_html("index.html")

fig.update_layout(title={"text": ""}, margin={"l": 10, "r": 10, "b": 10, "t": 10})
fig.write_json("figure.json")

# orca graph .\figure.json -o figure.png --mathbox-access-token "pk.eyJ1Ijoiam9oYW5uZ29sdHoiLCJhIjoiY2tjbWFiaHRsMjBzcjJycXFuM3pseDEybSJ9.8MIAWvV1iG11vsGgLpmJsA" --scale 3 --width 700 --height 900
