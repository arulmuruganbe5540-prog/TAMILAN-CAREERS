/* Shared site experience loader. Text selection, copy, context menus and keyboard shortcuts remain available. */
(function(){
"use strict";
function loadScript(src){
  if(document.querySelector('script[src="'+src+'"]')) return;
  var script=document.createElement("script");
  script.src=src;
  script.defer=true;
  document.head.appendChild(script);
}
loadScript("assets/global-experience.js?v=20261120-4");
loadScript("assets/professional-footer.js?v=20261120-4");
/* Load the configured AdSense publisher script once; ad placement remains controlled by publisher settings. */
var adSrc="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-5514219463771418";
if(!document.querySelector('script[src*="pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"]')){
  var ad=document.createElement("script");
  ad.async=true;
  ad.src=adSrc;
  ad.crossOrigin="anonymous";
  document.head.appendChild(ad);
}
})();
