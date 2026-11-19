/* TAMILAN CAREERS — verified government recruitment feed.
   Public display only: reads records already published by the trusted admin workflow.
   It never creates or approves notices in the browser. */
(() => {
  const host = document.getElementById("tcGovernmentFeed");
  if (!host) return;
  const SUPABASE_URL = "https://qkmljuuusfjowexvybvy.supabase.co";
  const SUPABASE_KEY = "sb_publishable_Wi6gltM_xFm1m4Dlgq727Q_83Rn58y2";
  const el = (tag, cls, value) => {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (value !== undefined && value !== null) n.textContent = String(value);
    return n;
  };
  const safeUrl = value => {
    try { const u = new URL(value); return u.protocol === "https:" ? u.href : ""; }
    catch { return ""; }
  };
  const dateText = value => {
    if (!value) return "See official notice";
    const d = new Date(value + (String(value).length === 10 ? "T00:00:00" : ""));
    return Number.isNaN(d.getTime()) ? String(value) : d.toLocaleDateString("en-IN");
  };
  const categoryLabels = {recruitment:"Recruitment Notice",result:"Exam Result",admit_card:"Hall Ticket / Admit Card",answer_key:"Answer Key",exam_update:"Exam Date / Update",other:"Government Notice"};
  const detailLabels = {
    post_names:"Posts", qualification:"Educational Qualification", education:"Educational Qualification",
    age_limit:"Age Limit", salary:"Salary", pay_scale:"Pay Scale",
    application_fee:"Application Fee", selection_process:"Selection Process",
    location:"Location", department:"Department", vacancies_breakdown:"Vacancy Details",
    notification_pdf_url:"Notice PDF", application_url:"Application Link", syllabus:"Syllabus", exam_date:"Exam Date", exam_name:"Exam / Recruitment"
  };
  function card(row) {
    const d = row.details && typeof row.details === "object" ? row.details : {};
    const article = el("article", "tc-gov-card");
    const state = d.state || (d.scope === "central" ? "Central Government" : "State Government");
    const head = el("div", "tc-gov-head");
    head.append(el("span","tc-gov-tag", categoryLabels[row.category] || "Official Notice"));
    const endValue = row.application_end ? String(row.application_end).slice(0,10) : "";
    const end = endValue ? new Date(endValue + "T23:59:59") : null;
    const expired = end && !Number.isNaN(end.getTime()) && end < new Date();
    head.append(el("span", expired ? "tc-gov-status expired" : "tc-gov-status", expired ? "Application Period Closed" : (row.application_end ? "Applications Open" : "Notice Posted")));
    article.append(head);
    article.append(el("h3","tc-gov-title",row.title));
    const detailLink=el("a","tc-gov-link","View Full Details →");detailLink.href="government-notice-details.html?id="+encodeURIComponent(row.id);article.append(detailLink);
    article.append(el("p","tc-gov-meta",[d.authority,state,row.notice_reference ? "Notice No.: "+row.notice_reference : ""].filter(Boolean).join(" · ")));
    const facts = el("div","tc-gov-facts");
    const pairs = [
      ["Notice Date",dateText(row.notice_date)],
      ["Vacancies",row.vacancies === null || row.vacancies === undefined ? "See Official PDF" : Number(row.vacancies).toLocaleString("en-IN")],
      ["Application Start",dateText(row.application_start)],
      ["Last Date",dateText(row.application_end)]
    ];
    pairs.forEach(([k,v]) => { const item=el("div","tc-gov-fact"); item.append(el("span","tc-gov-label",k),el("strong","",v)); facts.append(item); });
    article.append(facts);
    if (row.eligibility_summary) article.append(el("p","tc-gov-eligibility",row.eligibility_summary));
    const extras = Object.entries(d).filter(([k,v]) => detailLabels[k] && v && !String(v).startsWith("http"));
    if (extras.length) {
      const list=el("dl","tc-gov-details");
      extras.forEach(([k,v])=>{list.append(el("dt","",detailLabels[k]));list.append(el("dd","",Array.isArray(v)?v.join(", "):(typeof v==="object"?JSON.stringify(v):v)));});
      article.append(list);
    }
    const links=el("div","tc-gov-links");
    const noticeUrl=safeUrl(d.notification_pdf_url)||safeUrl(row.official_url);
    if (noticeUrl) { const a=el("a","tc-gov-link",d.notification_pdf_url?"Original Government PDF ↗":"Official Source Notice ↗");a.href=noticeUrl;a.target="_blank";a.rel="noopener noreferrer";links.append(a); }
    const applyUrl=safeUrl(d.application_url)||safeUrl(d.apply_url);
    if (applyUrl) { const a=el("a","tc-gov-link apply","Official Application ↗");a.href=applyUrl;a.target="_blank";a.rel="noopener noreferrer";links.append(a); }
    article.append(links);
    article.append(el("p","tc-gov-source","Source: "+(d.authority||"Official Government Website")+" · Verify details using the source link."));
    return article;
  }
  const style=el("style","");
  style.textContent=`
    #tcGovernmentFeed{margin:22px 0;padding:18px;background:#fff;border:1px solid #e1e8f1;border-radius:14px}
    #tcGovernmentFeed .tc-gov-toolbar{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap}
    #tcGovernmentFeed h2{margin:0;color:#174777;font-size:21px}
    #tcGovernmentFeed .tc-gov-note{color:#69788e;font-size:13px;line-height:1.7;margin:8px 0 14px}
    #tcGovernmentFeed .tc-gov-period{padding:10px;border:1px solid #d6dfeb;border-radius:8px;background:#fff}
    #tcGovernmentFeed .tc-gov-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:13px}
    #tcGovernmentFeed .tc-gov-card{border:1px solid #e2e8f1;border-radius:12px;padding:16px;background:#fbfdff;min-width:0}
    #tcGovernmentFeed .tc-gov-head{display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap}
    #tcGovernmentFeed .tc-gov-tag,#tcGovernmentFeed .tc-gov-status{font-size:11px;padding:5px 8px;border-radius:6px;background:#eaf4ff;color:#17558d}
    #tcGovernmentFeed .tc-gov-status.expired{background:#fff1e8;color:#9a4a1c}
    #tcGovernmentFeed .tc-gov-title{font-size:16px;line-height:1.5;color:#153e6a;margin:12px 0 6px}
    #tcGovernmentFeed .tc-gov-meta,#tcGovernmentFeed .tc-gov-source{font-size:12px;color:#69788e;line-height:1.6}
    #tcGovernmentFeed .tc-gov-facts{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:12px 0}
    #tcGovernmentFeed .tc-gov-fact{background:#f1f6fc;border-radius:8px;padding:9px;min-width:0}
    #tcGovernmentFeed .tc-gov-label{display:block;color:#6b7890;font-size:11px;margin-bottom:3px}
    #tcGovernmentFeed .tc-gov-fact strong{font-size:13px;overflow-wrap:anywhere}
    #tcGovernmentFeed .tc-gov-eligibility{font-size:13px;line-height:1.7;color:#35465d}
    #tcGovernmentFeed .tc-gov-details{display:grid;grid-template-columns:minmax(95px,auto) 1fr;gap:5px 10px;font-size:12px;line-height:1.6}
    #tcGovernmentFeed .tc-gov-details dt{font-weight:700;color:#53647b}
    #tcGovernmentFeed .tc-gov-details dd{margin:0;color:#25364c;overflow-wrap:anywhere}
    #tcGovernmentFeed .tc-gov-links{display:flex;gap:8px;flex-wrap:wrap;margin:12px 0}
    #tcGovernmentFeed .tc-gov-link{display:inline-block;padding:9px 11px;border-radius:7px;background:#eaf4ff;color:#145b9a;font-size:12px;font-weight:700}
    #tcGovernmentFeed .tc-gov-link.apply{background:#e7f5ee;color:#17623e}
    #tcGovernmentFeed .tc-gov-empty{padding:18px;text-align:center;background:#f7f9fc;border-radius:9px;color:#68778c;font-size:13px}
    @media(max-width:650px){#tcGovernmentFeed .tc-gov-grid{grid-template-columns:1fr}#tcGovernmentFeed .tc-gov-toolbar{align-items:flex-start}}
  `;
  document.head.append(style);
  const toolbar=el("div","tc-gov-toolbar");
  const title=el("h2","","Verified Government Notices and Exam Updates");
  const period=el("select","tc-gov-period");
  period.innerHTML='<option value="12" selected>Last 12 Months</option><option value="6">Last 6 Months</option>';
  const category=el("select","tc-gov-period");
  category.innerHTML='<option value="all">All Categories</option><option value="recruitment">Recruitment Notices</option><option value="admit_card">Hall Ticket / Admit Card</option><option value="result">Exam Results</option><option value="answer_key">Answer Key</option><option value="exam_update">Exam Dates / Other Updates</option><option value="other">Other Notices</option>';
  toolbar.append(title,period,category);host.append(toolbar);
  host.append(el("p","tc-gov-note","Recruitment notices, hall tickets, results, answer keys and exam updates verified against official government sources. Older records are displayed with their actual notice dates."));
  const status=el("p","tc-gov-note","Loading notices…");host.append(status);
  const grid=el("div","tc-gov-grid");host.append(grid);
  async function load(){
    status.textContent="Loading notices…";grid.replaceChildren();
    try{
      if(!window.supabase?.createClient) throw new Error("The information service is currently unavailable.");
      const client=window.supabase.createClient(SUPABASE_URL,SUPABASE_KEY);
      const [noticeResult,jobResult]=await Promise.all([
        client.from("government_notices")
          .select("id,title,category,official_url,notice_reference,notice_date,application_start,application_end,vacancies,eligibility_summary,details,is_active")
          .eq("is_active",true).order("notice_date",{ascending:false}).limit(500),
        client.from("jobs").select("*").eq("status","published").eq("job_kind","government").order("created_at",{ascending:false}).limit(500)
      ]);
      if(noticeResult.error) throw noticeResult.error;
      if(jobResult.error) throw jobResult.error;
      const postedJobs=(jobResult.data||[]).map(j=>{
        const authority=String(j.recruitment_authority||"").toLowerCase();
        const location=String(j.location||"").toLowerCase();
        const isTamilNadu=authority.includes("tn")||authority.includes("tamil nadu")||location.includes("tamil nadu");
        const salary=j.salary_min||j.salary_max?("₹ "+(j.salary_min||"")+(j.salary_min&&j.salary_max?" – ":"")+(j.salary_max||"")):"";
        const extra=(label)=>{const match=String(j.description||"").match(new RegExp(label+"\\s*:\\s*([^\\n]+)"));return match?match[1].trim():"";};
        const details={
          scope:isTamilNadu?"state":"central",
          state:isTamilNadu?"Tamil Nadu":"India",
          authority:j.recruitment_authority||j.company_name||"Government Department",
          department:j.recruitment_authority||"",
          qualification:j.education_level||"",
          syllabus:extra("Syllabus"),
          exam_date:extra("Exam Date"),
          exam_name:extra("Exam / Recruitment"),
          vacancies_breakdown:extra("Post-wise Vacancies"),
          age_limit:j.age_limit,
          salary,
          selection_process:j.selection_process,
          location:j.location,
          application_url:j.application_url,
          notification_pdf_url:j.official_notification_url
        };
        return {
          id:j.id,title:j.job_title||j.title||"Government Recruitment",category:"recruitment",
          official_url:j.official_notification_url||j.official_website_url||j.application_url,
          notice_reference:j.notification_number,notice_date:j.notification_date||j.published_at||j.created_at,
          application_start:extra("Application Start Date")||null,application_end:j.application_deadline,
          vacancies:j.vacancies??j.vacancy_count??j.openings??null,
          eligibility_summary:j.education_level||j.experience_min||"",
          details,is_active:true
        };
      });
      const data=[...(noticeResult.data||[]),...postedJobs];
      const months=Number(period.value);
      const cutoff=new Date();cutoff.setMonth(cutoff.getMonth()-months);
      const selectedCategory=category.value;
      const scope=host.dataset.scope||"all",stateFilter=host.dataset.state||"";
      const rows=data.filter(r=>{
        if(!r.notice_date) return false;
        const dt=new Date(String(r.notice_date).slice(0,10)+"T00:00:00");if(dt<cutoff)return false;
        const d=r.details||{};
        if(selectedCategory!=="all" && r.category!==selectedCategory)return false;
        if(scope==="central" && d.scope!=="central")return false;
        if(scope==="state" && d.scope!=="state")return false;
        if(stateFilter==="Tamil Nadu" && String(d.state||"").toLowerCase()!=="tamil nadu")return false;
        if(stateFilter==="other" && String(d.state||"").toLowerCase()==="tamil nadu")return false;
        return true;
      });
      rows.sort((a,b)=>new Date(String(b.notice_date).slice(0,10))-new Date(String(a.notice_date).slice(0,10)));
      if(!rows.length){status.textContent="No officially verified and published recruitment notices are available for this period.";grid.append(el("div","tc-gov-empty","New notices will appear here after verification. Vacancy counts and eligibility details are not estimated."));return;}
      rows.forEach(r=>grid.append(card(r)));
      status.textContent=rows.length+" verified government records · last "+months+" months";
    }catch(e){status.textContent="Notices could not be loaded. Please try again later.";grid.append(el("div","tc-gov-empty","Information service or permission verification is required."));}
  }
  period.addEventListener("change",load);
  category.addEventListener("change",load);
  load();
})();