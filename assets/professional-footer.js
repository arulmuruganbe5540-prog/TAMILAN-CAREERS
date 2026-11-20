(function(){
"use strict";
if(window.__tcProfessionalFooterLoaded)return;
window.__tcProfessionalFooterLoaded=true;
function addSuperAdminLink(footer){
 if(!footer||footer.querySelector("[data-tc-super-admin-link]"))return;
 var style=document.getElementById("tc-super-admin-footer-style");
 if(!style){style=document.createElement("style");style.id="tc-super-admin-footer-style";style.textContent=".tc-super-admin-footer-link{display:inline-flex!important;align-items:center;justify-content:center;margin:18px auto 0!important;padding:8px 13px;border:1px solid #ffffff35;border-radius:8px;color:#9fb5d2!important;font-size:11px!important;text-decoration:none!important}.tc-super-admin-footer-link:hover{color:#fff!important;border-color:#6bd8f0;background:#ffffff0b}";document.head.appendChild(style)}
 var wrap=document.createElement("div");wrap.style.textAlign="center";wrap.style.borderTop="1px solid #ffffff18";wrap.style.marginTop="12px";wrap.style.paddingTop="8px";
 var link=document.createElement("a");link.href="admin-login.html";link.className="tc-super-admin-footer-link";link.textContent="Super Admin Login";link.setAttribute("data-tc-super-admin-link","true");link.rel="nofollow";
 wrap.appendChild(link);footer.appendChild(wrap);
}
function render(){
 if(!document.body)return;
 if(/(?:^|\/)(?:login|register|admin-login|admin-control|admin-design-studio|admin-security|admin-job-post|admin-community-posts|admin-global-control)(?:\.html)?$/i.test(window.location.pathname))return;
 var existingFooter=document.querySelector("body footer");
 if(existingFooter){addSuperAdminLink(existingFooter);return;}
 var style=document.getElementById("tc-professional-footer-style");
 if(!style){
  style=document.createElement("style");style.id="tc-professional-footer-style";
  style.textContent=".tc-footer{background:#061229;color:#cbd8eb;padding:48px 22px 22px;margin-top:44px;border-top:1px solid #18345b;font-family:inherit}.tc-footer *{box-sizing:border-box}.tc-footer-inner{max-width:1200px;margin:auto}.tc-footer-grid{display:grid;grid-template-columns:1.5fr repeat(3,minmax(0,1fr));gap:30px;padding-bottom:30px}.tc-footer-brand{font-weight:900;letter-spacing:.7px;color:#fff;font-size:20px}.tc-footer-brand span{color:#58d7ed}.tc-footer p{color:#aebed4;font-size:13px;line-height:1.8;margin:12px 0}.tc-footer h2{font-size:13px;color:#fff;margin:2px 0 14px;letter-spacing:.35px}.tc-footer a{display:block;color:#b9c9df;text-decoration:none;font-size:12px;line-height:1.8;margin:7px 0;overflow-wrap:anywhere}.tc-footer a:hover{color:#65def0;text-decoration:underline}.tc-footer .tc-footer-email{color:#9deaff;font-weight:700}.tc-footer .tc-footer-domain{font-size:10px;letter-spacing:1px;color:#8fa7c8;font-weight:800}.tc-footer-bottom{border-top:1px solid #ffffff20;padding-top:17px;display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap;color:#91a5c2;font-size:11px;line-height:1.7}.tc-footer-bottom strong{color:#65d9ed}@media(max-width:760px){.tc-footer{padding:36px 17px 20px;margin-top:32px}.tc-footer-grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}.tc-footer-about{grid-column:1/-1}}@media(max-width:420px){.tc-footer-grid{grid-template-columns:1fr}.tc-footer-about{grid-column:auto}}";
  document.head.appendChild(style);
 }
 var footer=document.createElement("footer");footer.className="tc-footer";footer.setAttribute("aria-label","TAMILAN CAREERS site information");
 footer.innerHTML='<div class="tc-footer-inner"><div class="tc-footer-grid">'+
 '<section class="tc-footer-about"><a class="tc-footer-brand" href="index.html">TAMILAN <span>CAREERS</span></a><p>Discover career information and job opportunities across government, private and international sectors. Check every vacancy with the official employer before applying.</p><h2>CONTACT & SUPPORT</h2><a class="tc-footer-email" href="mailto:arulmuruganbe5540@gmail.com">arulmuruganbe5540@gmail.com</a><p class="tc-footer-domain">WWW.TAMILANCAREERS.IN</p></section>'+
 '<section><h2>EXPLORE JOBS</h2><a href="jobs.html">All Jobs</a><a href="indian-government-jobs.html">Central Government Jobs</a><a href="tamil-nadu-government-jobs.html">Tamil Nadu Government Jobs</a><a href="jobs.html?job_kind=private">Private Jobs</a><a href="jobs.html?job_kind=foreign">International Jobs</a></section>'+
 '<section><h2>FOR CANDIDATES & EMPLOYERS</h2><a href="job-search-guide.html">Job Search Guide</a><a href="exam-preparation.html">Exam Preparation</a><a href="login.html">Job Seeker Login</a><a href="login.html">Employer Login</a><a href="help.html">Help Centre & FAQs</a></section>'+
 '<section><h2>ABOUT, SAFETY & POLICIES</h2><a href="about.html">About Us</a><a href="help.html">Job Safety Guidance</a><a href="privacy.html">Privacy Policy</a><a href="terms.html">Terms of Use</a><a href="cookie-policy.html">Cookie Policy</a></section>'+
 '</div><div class="tc-footer-bottom"><span>© '+new Date().getFullYear()+' <strong>TAMILAN CAREERS</strong>. All rights reserved.</span><span>WWW.TAMILANCAREERS.IN · Discover opportunities. Build your future.</span></div></div>';
 document.body.appendChild(footer);addSuperAdminLink(footer);
}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",render,{once:true});else render();
})();