// user-overrides.js
// Personal overrides on top of arkenfox user.js
// See: https://github.com/arkenfox/user.js/wiki/3.1-Overrides
//
// Appended after arkenfox by run_after_50-firefox-userjs, which writes the
// result as user.js into the default Firefox profile on every chezmoi apply.
// Firefox applies it on its next start. A pref removed here stays in the
// profile's prefs.js: close Firefox and run arkenfox' prefsCleaner.bat in the
// profile folder to reset it.
//
// Leave network.http.windows-sso.enabled (Entra SSO) and
// security.enterprise_roots.enabled (corporate CAs) alone: IT owns those, see
// about:policies.

// Disable AI chatbot (Firefox sidebar)
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.chat.shortcuts", false);
user_pref("browser.ml.chat.shortcuts.longPress", false);

// Disable the built-in VPN ("IP Protection") and its toolbar button. Newer
// than arkenfox v144, so arkenfox does not cover it.
user_pref("browser.ipProtection.enabled", false);

// Suppress "older version" warning when using Firefox ESR with an existing profile
user_pref("browser.startup.upgradeDialog.enabled", false);

/* [EXAMPLE OVERRIDES - uncomment and adjust as needed]

// Keep your language (arkenfox forces en-US)
user_pref("intl.accept_languages", "nb-NO, nb, no, en-US, en");

// Allow specific sites to use WebGL (arkenfox disables it)
// user_pref("webgl.disabled", false);

// Enable DRM (arkenfox disables it)
// user_pref("media.eme.enabled", true);

*/

// arkenfox clears cookies and site data when Firefox closes (2811), so every
// restart signs you out (Microsoft 365 included). Keep chosen sites signed in
// with Settings > Privacy & Security > Cookies and Site Data > Manage
// Exceptions > Allow, or keep all of them:
// user_pref("privacy.clearOnShutdown_v2.cookiesAndStorage", false);

user_pref("extensions.pocket.enabled", false); //fully disable pocket
user_pref("identity.fxaccounts.enabled", true); //enable sync
user_pref("places.history.enabled", true); // enable history
// Figma compatibility: requires modern JS engines and WebAssembly.
user_pref("javascript.options.ion", true);
user_pref("javascript.options.asmjs", true);
user_pref("javascript.options.wasm", true);
user_pref("javascript.options.baselinejit", true);
user_pref("dom.webaudio.enabled", true);
user_pref("browser.safebrowsing.downloads.remote.enabled", true);
user_pref("browser.safebrowsing.phishing.enabled", true);
user_pref("browser.safebrowsing.malware.enabled", true);
user_pref("dom.webnotifications.enabled", true); // enable notifications
user_pref("browser.urlbar.suggest.history", true); //suggestions from history
user_pref("browser.urlbar.suggest.openpage", true); // suggestions from open pages
user_pref("browser.urlbar.suggest.topsites", false); //no top sites in the suggestions
user_pref("browser.formfill.enable", false); // disable form history suggestions
user_pref("signon.management.page.breach-alerts.enabled", true);
user_pref("layout.spellcheckDefault", 0); //no spell-check
user_pref("signon.rememberSignons", false); //never ask to save passwords
user_pref("extensions.formautofill.creditCards.enabled", false); //disable saving payment methods
user_pref("extensions.formautofill.addresses.enabled", false); //disable saving addresses
user_pref("permissions.default.geo", 2); //deny location access
user_pref("geo.enabled", false); //fullly disable location acces
user_pref("media.navigator.enabled", false); //disabled some media features (no camera/mic for web calls)
// user_pref("media.peerconnection.enabled", false); // disable WebRTC (privacy)
// user_pref("dom.security.https_only_mode", true); // enforce HTTPS-Only mode
// user_pref("dom.security.https_only_mode_ever_enabled", true);
user_pref("network.IDN_show_punycode", true); // show punycode to reduce IDN spoof risk



//Section 2: Re-enabled features
user_pref("keyword.enabled", true); //search from the urlbar
user_pref("browser.startup.page", 1); //start on homepage
user_pref("browser.startup.homepage", "about:home"); //Sets homepage
user_pref("browser.newtabpage.enabled", true); //enable Firefox Home for new tabs
user_pref("browser.download.useDownloadDir", false); //always download files to the System Download Directory
user_pref("browser.urlbar.suggest.searches", false); //disables search suggestions in the url-bar



//Section 3: Misc changes (mostly personal prefrence)
user_pref("browser.compactmode.show", true); //compact mode is displayed by default
user_pref("browser.uidensity", 1); //enables compact mode by default
user_pref("privacy.spoof_english", 2); //spoofs english by default

// Figma compatibility: keep WebGL enabled.
user_pref("webgl.disabled", false);



//Section 4: From the Linux repo's policies.json "Preferences" and policies
// that have a pref equivalent (this repo sets no enterprise policies).
// Not locked like the policies were, but user.js resets them on every start.
// Firefox Home (re-enabled above) without widgets, stories and shortcuts:
user_pref("browser.newtabpage.activity-stream.widgets.enabled", false);
user_pref("browser.newtabpage.activity-stream.widgets.system.enabled", false);
user_pref("browser.newtabpage.activity-stream.showWeather", false);
user_pref("browser.newtabpage.activity-stream.widgets.weather.enabled", false);
user_pref("browser.newtabpage.activity-stream.newtabWallpapers.enabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.highlights", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.shell.checkDefaultBrowser", false); // DontCheckDefaultBrowser
user_pref("browser.aboutwelcome.enabled", false); // UserMessaging.SkipOnboarding
user_pref("browser.preferences.moreFromMozilla", false); // UserMessaging.MoreFromMozilla
user_pref("browser.urlbar.quicksuggest.dataCollection.enabled", false); // FirefoxSuggest.ImproveSuggest
