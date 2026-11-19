const languageButton=document.getElementById('language');let currentLanguage='en';
function setLanguage(lang){currentLanguage=lang;document.documentElement.lang=lang;document.querySelectorAll('[data-en]').forEach(el=>{const value=el.dataset[lang];if(value!==undefined){if(el.tagName==='H1')el.innerHTML=value.replace(/\n/g,'<br>');else el.textContent=value;}});languageButton.textContent=lang==='en'?'FR':'EN';}
languageButton.addEventListener('click',()=>setLanguage(currentLanguage==='en'?'fr':'en'));
document.getElementById('menu').addEventListener('click',()=>document.getElementById('nav').classList.toggle('open'));
document.querySelectorAll('#nav a').forEach(a=>a.addEventListener('click',()=>document.getElementById('nav').classList.remove('open')));
document.getElementById('year').textContent=new Date().getFullYear();
document.getElementById('contactForm').addEventListener('submit',e=>{e.preventDefault();const d=new FormData(e.target);const subject=encodeURIComponent('Website enquiry from '+d.get('name'));const body=encodeURIComponent('Name: '+d.get('name')+'\nEmail: '+d.get('email')+'\n\n'+d.get('message'));window.location.href='mailto:greatgodhelpinghandsfoundation@gmail.com?subject='+subject+'&body='+body;});
