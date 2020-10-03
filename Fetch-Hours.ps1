Function Get-BüntingSundayMarkets {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)][string] $Chain,
		[Parameter(Mandatory=$true)][uri] $BaseUri
	)

	$markets = Invoke-RestMethod -Uri ([Uri]::New($BaseUri, '/wp-json/wp/v2/wqwarenhaus?per_page=100'))
	$marketgeodata = $coords |
		ForEach-Object {
			Invoke-RestMethod -Uri ([Uri]::New($BaseUri, "/wp-admin/admin-ajax.php?action=store_search&lat=$($_.lat)&lng=$($_.lon)&max_results=50&search_radius=100"))
		} | ForEach-Object { $_ }
	$markets | ForEach-Object -Parallel {
		$uri = $_.link
		$marketpage = Invoke-RestMethod $uri
		$sundayOpeningHours = ($marketpage | Select-String 'Sonntag<\/strong><br>(([^<])*)').Matches.Groups
		if ($sundayOpeningHours) {
			$latlon = $using:marketgeodata | Where-Object url -eq $uri | Select-Object -First 1
			@{
				 'chain'=$using:Chain
				 'label'=$using:Chain + ' ' + $_.title.rendered
				 'lat'=$latlon.lat
				 'lon'=$latlon.lng
				 'Hours'="Sonntag $($sundayOpeningHours[1].Value)"
			 }
		}
	}
}


# Netto MD
{((Invoke-RestMethod -Uri 'https://www.netto-online.de/INTERSHOP/web/WFS/Plus-NettoDE-Site/de_DE/-/EUR/ViewNettoStoreFinder-GetStoreItems' -Method 'POST' -Body 's=45&n=55&w=5&e=15') | 
		Where-Object store_opening -notlike '*geschlossen*') | 
		Foreach-Object { @{ 
			'chain'='Roter Netto' ; 
			'label'=$_.store_name; 
			'lat'=$_.coord_latitude; 
			'lon'=$_.coord_longitude; 
			'hours'=($_.store_opening | Select-String 'So.*Uhr').matches.value
}}},
# Netto Scottie
{(Invoke-RestMethod https://netto.de/umbraco/api/StoresData/StoresV2) | 
		Where-Object { $_.hours | 
			Where-Object { $_.date.DayOfWeek -eq [System.DayOfWeek]::Sunday -and -not $_.closed }} | 
		Foreach-Object { @{ 
			'chain'='Schwarzer Netto'; 
			'label'=$_.name; 
			'lat'=$_.coordinates[1]; 
			'lon'=$_.coordinates[0]; 
			'hours'=('Sonntag: ' + (($_.hours | 
				Where-Object { $_.date.DayOfWeek -eq [System.DayOfWeek]::Sunday }) | 
				Select-Object open, close).
				PSObject.Properties.Value.
				ToShortTimeString() -Join ' – ')
}}},
# Penny
{((Invoke-RestMethod https://www.penny.de/.rest/market).Results | Where-Object ClosesAtSunday -ne '00:00') | ForEach-Object { @{ 
	'chain'='Penny'; 
	'label'=$_.marketName; 
	'lat'=$_.latitude; 
	'lon'=$_.longitude; 
	'hours'=($_.openingSentence | Select-String 'Sonntag.*').Matches.Value 
}}},
# Aldi
{(Invoke-RestMethod 'https://www.aldi-sued.de/de/de/.get-stores-in-radius.json?_1600100467773&latitude=52.51214009999999&longitude=13.414046&radius=2500').
		Stores | 
		Where-Object CountryCode -eq 'DE' | 
		Where-Object { -not $_.openUntil.So.closed } | 
		ForEach-Object { @{ 
			'chain'="Aldi $(@{'N'='Nord';'S'='Süd'}[$_.StoreType])"; 
			'label'="Aldi $(@{'N'='Nord';'S'='Süd'}[$_.StoreType])"; 
			'lat'=$_.latitude; 
			'lon'=$_.longitude; 
			'hours'=($_.openingHours | Select-String 'So.*').Matches.Value
}}},
# Lidl
{
	$token = (Invoke-RestMethod 'https://www.lidl.de/de/asset/other/storeFinder.js' |
		Select-String 'DATA_SOURCE_QUERY_KEY:{DE:"(.*?)"').Matches.Groups[1].Value
	$sessionId = (Invoke-RestMethod "https://dev.virtualearth.net/webservices/v1/LoggingService/LoggingService.svc/Log?entry=0&fmt=1&type=3&group=MapControl&auth=$token").sessionId
	0..12 | Foreach-Object { (Invoke-RestMethod "https://spatial.virtualearth.net/REST/v1/data/ab055fcbaac04ec4bc563e65ffa07097/Filialdaten-SEC/Filialdaten-SEC?`$select=OpeningTimes,Longitude,Latitude&`$top=250&`$skip=$($_*250)&key=$sessionId&`$format=json&spatialFilter=nearby(51.9,10.3,1000)").d.results } |
			Where-Object OpeningTimes -notmatch 'So closed' |
			ForEach-Object { @{
				'chain'='Lidl';
				'label'='Lidl';
				'lat'=$_.Latitude;
				'lon'=$_.Longitude;
				'hours'=($_.OpeningTimes | Select-String 'So[^<]+').Matches.Value
		}}
},
# Edeka
{
	$href = '/api/marketsearch/markets?size=1000'; 
	$result=@(); 
	do { 
		$response = Invoke-RestMethod "https://www.edeka.de$href"; 
		$href = $response._links.next.href; 
		$result += $response.markets 
	} while ($href -ne $null); 
	$result | Where-Object { $_.businessHours.sunday -and $_.distributionChannel.type -ne 'Andere' } | 
	Foreach-Object { @{ 
		'chain'='Edeka'; 
		'label'=$_.name; 
		'lat'=$_.coordinates.lat; 
		'lon'=$_.coordinates.lon; 
		'hours'="Sonntag: $($_.businessHours.sunday.from) – $($_.businessHours.sunday.to)" 
}}},
# Rewe
{0..7 | Foreach-Object { 
		(Invoke-RestMethod -Uri "https://www.rewe.de/market/content/marketsearch" `
			-Method "POST" `
			-Headers @{
				"accept-encoding"="gzip, deflate"
				"accept-language"="de" } `
			-Form @{
				"searchString"="rewe"
				"city"=""
				"page"=$_
				"pageSize"=500
			}).markets } |
		Where-Object { $days = $_.openingHours.condensed.days; $days -and $days.Contains('So') } |
		Foreach-Object {
			$sundayOpening = $_.openingHours.condensed | Where-Object { $_.days.Contains('So') }
			@{
				'chain'='Rewe'
				'label'=$_.headline
				'lat'=$_.geolocation.latitude
				'lon'=$_.geolocation.longitude
				'hours'="$($sundayOpening.days) $($sundayOpening.hours)"
			}
}},
# Famila
{
	Get-BüntingSundayMarkets -Chain 'Famila' -BaseUri 'https://www.famila-nordost.de/'
},
# Hit Ulrich
{@(@{'chain'='Hit'; 'label'='Hit Berlin Zoo'; 'lat'=52.506395; 'lon'=13.331433; 'hours'='Sonntag: 09:00 – 22:00'})} | 
Foreach-Object { Start-Job $_ } |
Foreach-Object -Parallel { Receive-Job $_ -Wait } |
Sort-Object chain |
%{[pscustomobject]$_}
