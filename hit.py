import requests
from bs4 import BeautifulSoup

base_uri = "https://www.hit.de"

soup = BeautifulSoup(requests.get(base_uri + "/marktauswahl.html").text, "html.parser")

location_links = [link.get("href") for link in soup.find(id="location-list").find_all("a") if link.get_text() == "Details"]

for location_uri in location_links:
    soup = BeautifulSoup(requests.get(base_uri + location_uri).text, "html.parser")
    hours_header = next(h3 for h3 in soup.find_all("h3") if h3.get_text() == "Öffnungszeiten")
    sunday_opening_hours = list(hours_header.parent.find(class_="row").children)[-2].text
    is_open_on_sundays = sunday_opening_hours != "\ngeschlossen\n"
    if is_open_on_sundays:
        print(location_uri)

