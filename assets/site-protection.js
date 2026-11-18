/* TAMILAN CAREERS copy deterrence; public browser content can never be made impossible to copy. */
(function(){'use strict';if(window.__tcCopyGuardInstalled)return;window.__tcCopyGuardInstalled=true;document.documentElement.classList.add('tc-protected');
const editable=el=>!!(el&&(el.closest('input,textarea,select,[contenteditable="true"],[contenteditable=""],.allow-copy')||el.isContentEditable));
document.addEventListener('contextmenu',e=>{if(!editable(e.target))e.preventDefault()},true);
document.addEventListener('selectstart',e=>{if(!editable(e.target))e.preventDefault()},true);
document.addEventListener('copy',e=>{if(!editable(e.target))e.preventDefault()},true);
document.addEventListener('cut',e=>{if(!editable(e.target))e.preventDefault()},true);
document.addEventListener('dragstart',e=>{if(e.target&&e.target.closest&&e.target.closest('img,svg'))e.preventDefault()},true);
document.addEventListener('keydown',e=>{if(editable(e.target))return;const k=String(e.key||'').toLowerCase();if((e.ctrlKey||e.metaKey)&&['c','x'].includes(k)){e.preventDefault();e.stopPropagation()}},true);
})();

/* Shared global locale, regional time and display preferences */
(function(){var s=document.createElement('script');s.src='assets/global-experience.js';s.defer=true;document.head.appendChild(s);})();
