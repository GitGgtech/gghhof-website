// Public, read-only rendering of approved GGHHOF CMS content.
(async()=>{
  const cfg=window.GGHHOF_SUPABASE;
  if(!cfg?.url||!cfg?.anonKey||!window.supabase)return;
  const db=window.supabase.createClient(cfg.url,cfg.anonKey);
  const el=id=>document.getElementById(id);
  const text=(tag,value,cls)=>{const n=document.createElement(tag);n.textContent=value||'';if(cls)n.className=cls;return n;};
  try{
    const {data:impact}=await db.from('public_impact').select('*').eq('id',1).maybeSingle();
    if(impact)Object.entries(impact).forEach(([k,v])=>{const n=document.querySelector(`[data-metric="${k}"]`);if(n)n.textContent=Number(v).toLocaleString();});
  }catch(e){console.info('Public impact figures are not available yet.');}
  try{
    const {data}=await db.from('team_members').select('full_name,position,biography,photo_url,category,display_order').eq('is_published',true).order('display_order');
    if(data?.length&&el('publicTeam')){const host=el('publicTeam');host.replaceChildren();data.forEach(person=>{const card=document.createElement('article');card.className='team-card';if(person.photo_url){const img=document.createElement('img');img.src=person.photo_url;img.alt=person.full_name;img.loading='lazy';img.className='cms-card-image';card.append(img);}else card.append(text('div',(person.full_name||'').split(/\s+/).map(x=>x[0]).slice(0,2).join('').toUpperCase(),'avatar'));card.append(text('h3',person.position),text('p',person.full_name));if(person.biography)card.append(text('small',person.biography));host.append(card);});}
  }catch(e){console.info('Published team content is not available yet.');}
  try{
    const {data}=await db.from('church_projects').select('project_name,location,description,status,image_url,start_date,completion_date').eq('is_published',true).order('created_at',{ascending:false});
    if(data?.length&&el('publicProjects')){const host=el('publicProjects');host.replaceChildren();data.forEach(project=>{const card=document.createElement('article');card.className='project-card';card.append(text('span',project.status==='completed'?'Completed':'Ongoing','status '+(project.status==='completed'?'status-complete':'status-progress')));if(project.image_url){const img=document.createElement('img');img.src=project.image_url;img.alt=project.project_name;img.loading='lazy';img.className='cms-card-image';card.append(img);}card.append(text('h3',project.project_name),text('p',[project.location,project.description].filter(Boolean).join(' — ')));host.append(card);});}
  }catch(e){console.info('Published projects are not available yet.');}
  try{
    const {data}=await db.from('media_items').select('title,description,media_type,media_url,category').eq('is_published',true).order('created_at',{ascending:false}).limit(18);
    if(data?.length&&el('publicGallery')){const host=el('publicGallery');host.replaceChildren();data.forEach(item=>{const card=document.createElement('article');card.className='gallery-placeholder';if(item.media_type==='image'){const img=document.createElement('img');img.src=item.media_url;img.alt=item.title;img.loading='lazy';img.className='cms-gallery-image';card.append(img);}else{const a=document.createElement('a');a.href=item.media_url;a.target='_blank';a.rel='noopener noreferrer';a.textContent='▶ Watch video';card.append(a);}card.append(text('b',item.title),text('small',[item.category,item.description].filter(Boolean).join(' · ')));host.append(card);});}
  }catch(e){console.info('Published gallery content is not available yet.');}
})();
