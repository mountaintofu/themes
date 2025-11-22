/* ===========================
   SIMPLE CONFIG
=========================== */
const defaultCity = "Ho Chi Minh City";
const defaultBg   = "Tokyo Night Abstract.png"; // replace with your packaged image or remote URL

let activeTimezone = "Asia/Ho_Chi_Minh"; // fallback if city lookup fails

/* ===========================
   INITIALIZE
=========================== */
document.addEventListener("DOMContentLoaded", () => {
    loadSettings();
    getWeather();

    updateClock();
    setInterval(updateClock, 1000);
});

/* ===========================
   CLOCK — uses city timezone
=========================== */
function updateClock() {
    const now = new Date();
    const time = now.toLocaleTimeString("en-US", {
        timeZone: activeTimezone,
        hour: "2-digit",
        minute: "2-digit",
        hour12: false
    });

    const clockEl = document.getElementById("clock");
    if (clockEl) clockEl.textContent = time;
}

/* ===========================
   WEATHER + TIMEZONE FETCH
=========================== */
async function getWeather() {
    const city = localStorage.getItem("startpage_city") || defaultCity;
    const weatherEl = document.getElementById("weather");

    if (!weatherEl) return;

    weatherEl.textContent = `Searching for ${city}…`;

    try {
        // 1. Geocode city
        const geo = await fetch(`https://geocoding-api.open-meteo.com/v1/search?name=${city}&count=1&format=json`);
        const geoData = await geo.json();

        if (!geoData.results || geoData.results.length === 0) {
            weatherEl.textContent = "City not found";
            return;
        }

        const place = geoData.results[0];
        activeTimezone = place.timezone;  // updates the clock's timezone

        // 2. Fetch weather
        const weatherReq = await fetch(
            `https://api.open-meteo.com/v1/forecast?latitude=${place.latitude}&longitude=${place.longitude}&current_weather=true`
        );
        const weather = await weatherReq.json();

        const temp = Math.round(weather.current_weather.temperature);
        const code = weather.current_weather.weathercode;


	weatherEl.textContent = "";  // clear first
	const locationSpan = document.createElement("span");
	locationSpan.textContent = `📍 ${place.name}: `;
	weatherEl.appendChild(locationSpan);

	const tempSpan = document.createElement("b");
	tempSpan.textContent = `${temp}°C`;
	weatherEl.appendChild(tempSpan);
	
	const descSpan = document.createElement("span");
	descSpan.textContent = ` – ${describeWeather(code)}`;
	weatherEl.appendChild(descSpan);


    } catch (err) {
        console.error(err);
        weatherEl.textContent = "Weather error";
    }
}

function describeWeather(code) {
    if (code === 0) return "☀️ Clear";
    if (code <= 3) return "☁️ Cloudy";
    if (code <= 48) return "🌫️ Fog";
    if (code <= 67) return "🌧️ Rain";
    if (code <= 77) return "🌨️ Snow";
    if (code <= 82) return "🌧️ Showers";
    if (code >= 95) return "⚡ Storm";
    return "🌥️";
}

/* ===========================
   SETTINGS
=========================== */
function loadSettings() {
    const bg = localStorage.getItem("startpage_bg") || defaultBg;
    const city = localStorage.getItem("startpage_city") || defaultCity;

    document.body.style.backgroundImage = `url('${bg}')`;

    const bgInput = document.getElementById("bgInput");
    const cityInput = document.getElementById("cityInput");

    if (bgInput) bgInput.value = bg;
    if (cityInput) cityInput.value = city;
}

function saveSettings() {
    const bgValue = document.getElementById("bgInput").value;
    const cityValue = document.getElementById("cityInput").value;

    localStorage.setItem("startpage_bg", bgValue);
    localStorage.setItem("startpage_city", cityValue);

    loadSettings();
    getWeather();
    toggleSettings();
}

function toggleSettings() {
    const modal = document.getElementById("settingsModal");
    if (modal) {
        modal.style.display = modal.style.display === "flex" ? "none" : "flex";
    }
}

/* ===========================
   SEARCH BAR
=========================== */
const searchForm = document.getElementById("searchForm");

if (searchForm) {
    searchForm.addEventListener("submit", e => {
        e.preventDefault();
        const q = document.getElementById("searchInput").value.trim();

        if (isURL(q)) {
            const url = /^https?:\/\//i.test(q) ? q : "https://" + q;
            window.location.href = url;
        } else {
            window.location.href = "https://duckduckgo.com/?q=" + encodeURIComponent(q);
        }
    });
}

function isURL(str) {
    return /^[a-z]+:\/\//i.test(str) || 
           /^[^\s]+\.[^\s]{2,}$/.test(str) ||
           /^localhost/.test(str) ||
           /^\d{1,3}(\.\d{1,3}){3}$/.test(str);
}
