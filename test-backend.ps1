# Test SpamFilms backend connectivity
Write-Host "Testing SpamFilms backend connections..." -ForegroundColor Yellow

$backends = @("https://fusme.link", "https://uxert.link")
$corsProxy = "https://corsproxy.io/?"

foreach ($backend in $backends) {
    Write-Host "`nTesting $backend..." -ForegroundColor Cyan
    
    # Test direct connection
    $directUrl = "$backend/movies/1?limit=5&sort=trending&local=en&contentLocale=en&showAll=1&genre=All&order=-1"
    Write-Host "Direct URL: $directUrl"
    
    try {
        $directResponse = Invoke-WebRequest -Uri $directUrl -TimeoutSec 10 -UseBasicParsing
        Write-Host "✓ Direct connection successful (Status: $($directResponse.StatusCode))" -ForegroundColor Green
        $directJson = $directResponse.Content | ConvertFrom-Json
        Write-Host "  Received $($directJson.Count) movies" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Direct connection failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test via CORS proxy
    $proxiedUrl = $corsProxy + $directUrl
    Write-Host "`nProxied URL: $proxiedUrl"
    
    try {
        $proxiedResponse = Invoke-WebRequest -Uri $proxiedUrl -TimeoutSec 10 -UseBasicParsing
        Write-Host "✓ Proxied connection successful (Status: $($proxiedResponse.StatusCode))" -ForegroundColor Green
        $proxiedJson = $proxiedResponse.Content | ConvertFrom-Json
        Write-Host "  Received $($proxiedJson.Count) movies" -ForegroundColor Green
        
        # Show first movie as sample
        if ($proxiedJson.Count -gt 0) {
            $firstMovie = $proxiedJson[0]
            Write-Host "`nSample movie:" -ForegroundColor Cyan
            Write-Host "  Title: $($firstMovie.title)"
            Write-Host "  Year: $($firstMovie.year)"
            Write-Host "  IMDb ID: $($firstMovie.imdb_id)"
            Write-Host "  Poster: $($firstMovie.images.poster)"
        }
    }
    catch {
        Write-Host "✗ Proxied connection failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n`nTest complete!" -ForegroundColor Yellow
