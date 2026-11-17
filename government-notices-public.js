/* TAMILAN CAREERS — verified government recruitment feed.
   Public display only: reads records already published by the trusted admin workflow.
   It never creates or approves notices in the browser. */
(() => {
  const host = document.getElementById("tcGovernmentFeed");
  if (!host) return;
  const SUPABASE_URL = "https://qkmljuuusfjowexvy.supabase.co";
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
    if (!value) return "அறிவிப்பில் பார்க்கவும்";
    const d = new Date(value + (String(value).length === 10 ? "T00:00:00" : ""));
    return Number.isNaN(d.getTime()) ? String(value) : d.toLocaleDateString("ta-IN");
  };
  const detailLabels = {
    post_names:"பதவிகள்", qualification:"கல்வித் தகுதி", education:"கல்வித் தகுதி",
    age_limit:"வயது வரம்பு", salary:"சம்பளம்", pay_scale:"ஊதிய நிலை",
    application_fee:"விண்ணப்பக் கட்டணம்", selection_process:"தேர்வு முறை",
    location:"பணியிடம்", department:"துறை", vacancies_breakdown:"காலியிட விவரம்",
    notification_pdf_url:"அறிவிப்பு PDF", application_url:"விண்ணப்ப இணைப்பு"
  };
  function card(row) {
    const d = row.details && typeof row.details === "object" ? row.details : {};
    const article = el("article", "tc-gov-card");
    const state = d.state || (d.scope === "central" ? "மத்திய அரசு" : "மாநில அரசு");
    const head = el("div", "tc-gov-head");
    head.append(el("span","tc-gov-tag", "அதிகாரப்பூர்வ அறிவிப்பு"));
    const end = row.application_end ? new Date(row.application_end + "T23:59:59") : null;
    const expired = end && !Number.isNaN(end.getTime()) && end < new Date();
    head.append(el("span", expired ? "tc-gov-status expired" : "tc-gov-status", expired ? "விண்ணப்பக் காலம் முடிந்தது" : (row.application_end ? "விண்ணப்பம் நடைபெறுகிறது" : "அறிவிப்பு பதிவு")));
    article.append(head);
    article.append(el("h3","tc-gov-title",row.title));
    article.append(el("p","tc-gov-meta",[d.authority,state,row.notice_reference ? "அறிவிப்பு எண்: "+row.notice_reference : ""].filter(Boolean).join(" · ")));
    const facts = el("div","tc-gov-facts");
    const pairs = [
      ["அறிவிப்பு தேதி",dateText(row.notice_date)],
      ["காலியிடங்கள்",row.vacancies === null || row.vacancies === undefined ? "அதிகாரப்பூர்வ PDF-ல் பார்க்கவும்" : Number(row.vacancies).toLocaleString("en-IN")],
      ["விண்ணப்ப தொடக்கம்",dateText(row.application_start)],
      ["கடைசி தேதி",dateText(row.application_end)]
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
    if (noticeUrl) { const a=el("a","tc-gov-link",d.notification_pdf_url?"அசல் அரசு PDF ↗":"அதிகாரப்பூர்வ மூல அறிவிப்பு ↗");a.href=noticeUrl;a.target="_blank";a.rel="noopener noreferrer";links.append(a); }
    const applyUrl=safeUrl(d.application_url)||safeUrl(d.apply_url);
    if (applyUrl) { const a=el("a","tc-gov-link apply","அதிகாரப்பூர்வ விண்ணப்பம் ↗");a.href=applyUrl;a.target="_blank";a.rel="noopener noreferrer";links.append(a); }
    article.append(links);
    article.append(el("p","tc-gov-source","மூலம்: "+(d.authority||"அதிகாரப்பூர்வ அரசு இணையதளம்")+" · தகவல் மூல இணைப்பில் சரிபார்க்கவும்."));
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
  const title=el("h2","","சரிபார்க்கப்பட்ட அரசு வேலை அறிவிப்புகள்");
  const period=el("select","tc-gov-period");
  period.innerHTML='<option value="6">கடந்த 6 மாதங்கள்</option><option value="12" selected>கடந்த 1 வருடம்</option>';
  toolbar.append(title,period);host.append(toolbar);
  host.append(el("p","tc-gov-note","அதிகாரப்பூர்வ அரசு மூலத்தில் உறுதிப்படுத்தப்பட்ட அறிவிப்புகள் மட்டும். அதிகபட்சம் 15 சமீபத்திய பதிவுகள் காட்டப்படும். விண்ணப்பக் காலம் முடிந்த பதிவுகள் தெளிவாகக் குறிக்கப்படும்."));
  const status=el("p","tc-gov-note","அறிவிப்புகள் ஏற்றப்படுகின்றன…");host.append(status);
  const grid=el("div","tc-gov-grid");host.append(grid);
  async function load(){
    status.textContent="அறிவிப்புகள் ஏற்றப்படுகின்றன…";grid.replaceChildren();
    try{
      if(!window.supabase?.createClient) throw new Error("தகவல் சேவை தற்போது கிடைக்கவில்லை.");
      const client=window.supabase.createClient(SUPABASE_URL,SUPABASE_KEY);
      const {data,error}=await client.from("government_notices")
        .select("id,title,category,official_url,notice_reference,notice_date,application_start,application_end,vacancies,eligibility_summary,details,is_active")
        .eq("is_active",true).eq("category","recruitment")
        .order("notice_date",{ascending:false}).limit(100);
      if(error) throw error;
      const months=Number(period.value);
      const cutoff=new Date();cutoff.setMonth(cutoff.getMonth()-months);
      const scope=host.dataset.scope||"all",stateFilter=host.dataset.state||"";
      const rows=(data||[]).filter(r=>{
        if(!r.notice_date) return false;
        const dt=new Date(r.notice_date+"T00:00:00");if(dt<cutoff)return false;
        const d=r.details||{};
        if(scope==="central" && d.scope!=="central")return false;
        if(scope==="state" && d.scope!=="state")return false;
        if(stateFilter==="Tamil Nadu" && String(d.state||"").toLowerCase()!=="tamil nadu")return false;
        if(stateFilter==="other" && String(d.state||"").toLowerCase()==="tamil nadu")return false;
        return true;
      }).slice(0,15);
      if(!rows.length){status.textContent="இந்த காலவரம்பில் இன்னும் அதிகாரப்பூர்வமாகச் சரிபார்த்து வெளியிடப்பட்ட வேலை அறிவிப்புகள் இல்லை.";grid.append(el("div","tc-gov-empty","புதிய அறிவிப்புகள் சரிபார்க்கப்பட்டதும் இங்கே தானாகத் தோன்றும். தற்போது காலியிட எண்ணிக்கை அல்லது தகுதி விவரங்கள் ஊகித்து காட்டப்படவில்லை."));return;}
      rows.forEach(r=>grid.append(card(r)));
      status.textContent=rows.length+" அதிகாரப்பூர்வ அறிவிப்புகள் · அதிகபட்சம் 15";
    }catch(e){status.textContent="அறிவிப்புகளை இப்போது ஏற்ற முடியவில்லை. பின்னர் மீண்டும் முயற்சிக்கவும்.";grid.append(el("div","tc-gov-empty","தகவல் சேவை / அனுமதி சரிபார்ப்பு தேவை."));}
  }
  period.addEventListener("change",load);
  load();
})();