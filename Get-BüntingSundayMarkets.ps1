Function Get-BüntingSundayMarkets {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)][string] $Chain,
		[Parameter(Mandatory=$true)][uri] $BaseUri,
		[Parameter(Mandatory=$true)][uri] $StoreUri
	)

	$coords = @{'lat'=54.10183; 'lon'=13.0715}, @{'lat'=53.57478; 'lon'=9.96662}, @{'lat'=54.59672; 'lon'=9.57515}

	$markets = Invoke-RestMethod ([Uri]::New($BaseUri,  $StoreUri, $False).ToString() + '?per_page=100')
	$marketgeodata = $coords |
		ForEach-Object {
			Invoke-RestMethod -Uri ([Uri]::New($BaseUri, "/wp-admin/admin-ajax.php?action=store_search&lat=$($_.lat)&lng=$($_.lon)&max_results=50&search_radius=100", $False))
		} | ForEach-Object { $_ }
	$markets | ForEach-Object {
		$uri = $_.link
		$marketpage = Invoke-RestMethod $uri
		$sundayOpeningHours = ($marketpage | Select-String 'Sonntag<\/strong><br>(([^<])*)').Matches.Groups
		if ($sundayOpeningHours) {
			$latlon = $marketgeodata | Where-Object url -like ($uri.Substring(0, $uri.Length - 1) + '*')  | Select-Object -First 1
			@{
				 'chain'=$Chain
				 'label'=$Chain + ' ' + $_.title.rendered
				 'lat'=$latlon.lat
				 'lon'=$latlon.lng
				 'hours'="Sonntag $($sundayOpeningHours[1].Value)"
			 }
		}
	}
}