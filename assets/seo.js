(function () {
  "use strict";
  var origin = window.location.origin;
  var path = window.location.pathname;
  var canonicalUrl = origin + path;
  if (path.endsWith("/index.html")) canonicalUrl = origin + path.slice(0, -10);
  var canonical = document.querySelector('link[rel="canonical"]');
  if (!canonical) { canonical = document.createElement("link"); canonical.rel = "canonical"; document.head.appendChild(canonical); }
  canonical.href = canonicalUrl;
  var ogUrl = document.querySelector('meta[property="og:url"]');
  if (!ogUrl) { ogUrl = document.createElement("meta"); ogUrl.setAttribute("property", "og:url"); document.head.appendChild(ogUrl); }
  ogUrl.content = canonicalUrl;
  if (path.endsWith("/") || path.endsWith("/index.html")) {
    var schema = {
      "@context": "https://schema.org",
      "@type": "WebSite",
      "name": "TAMILAN CAREERS",
      "alternateName": "Tamilan Careers",
      "url": origin + path,
      "inLanguage": "en",
      "potentialAction": {
        "@type": "SearchAction",
        "target": origin + path.replace(/index\.html$/, "") + "jobs.html?q={search_term_string}",
        "query-input": "required name=search_term_string"
      }
    };
    var script = document.getElementById("tc-website-jsonld");
    if (!script) { script = document.createElement("script"); script.type = "application/ld+json"; script.id = "tc-website-jsonld"; document.head.appendChild(script); }
    script.textContent = JSON.stringify(schema);

    var organization = {
      "@context": "https://schema.org",
      "@type": "Organization",
      "name": "TAMILAN CAREERS",
      "alternateName": "Tamilan Careers",
      "url": origin + "/",
      "description": "A job discovery platform for government, private-sector and international career opportunities.",
      "email": "arulmuruganbe5540@gmail.com",
      "contactPoint": [{
        "@type": "ContactPoint",
        "contactType": "customer support",
        "email": "arulmuruganbe5540@gmail.com",
        "availableLanguage": ["English"]
      }]
    };
    var organizationScript = document.getElementById("tc-organization-jsonld");
    if (!organizationScript) { organizationScript = document.createElement("script"); organizationScript.type = "application/ld+json"; organizationScript.id = "tc-organization-jsonld"; document.head.appendChild(organizationScript); }
    organizationScript.textContent = JSON.stringify(organization);
  }
})();
(function(){var s=document.createElement('script');s.src='assets/global-experience.js';s.defer=true;document.head.appendChild(s);})();
