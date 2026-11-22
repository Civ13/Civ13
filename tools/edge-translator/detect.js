// Language detection for chat lines, used because Edge's LanguageDetector
// reports "Model not available" on the host (Edge 158, 2026-11-21). Script
// ranges settle most non-Latin languages; Latin-script languages are scored by
// common words and letters. Returns an ISO 639-1 code from LANGS, or 'und'.
'use strict';

const MIN_LETTERS = 3;

const LANGS = ['en', 'es', 'pt', 'fr', 'de', 'it', 'nl', 'pl', 'ru', 'uk', 'tr', 'sv', 'fi', 'cs', 'ro',
  'el', 'ar', 'hi', 'id', 'vi', 'th', 'zh', 'ja', 'ko'];

const WORDS = {
  en: 'the a an and is are you i to of it that this what where have do not can we they my your for with on at be was just get go me so yes hello hi hey thanks good morning night okay he she his her makes made into from'.split(' '),
  es: 'el la los las de que y en un una es por con para no se lo como pero mas muy hola gracias donde esta estoy tengo quiero vamos aqui bien amigo buenos buenas dias tardes noches adios hasta luego si tal estas eres soy hay todo nada bueno buena senor'.split(' '),
  pt: 'o a os as de que e em um uma nao com para por voce eu ele ela muito obrigado obrigada onde esta estou tenho quero vamos aqui bem tudo bom boa dia noite tarde ola tchau sim voces tambem'.split(' '),
  fr: 'le la les des de du et est un une je tu il elle nous vous pas que qui pour avec dans sur bonjour merci oui ou suis ai bonsoir salut revoir mes ami amis comment ca va tres bien'.split(' '),
  de: 'der die das und ist ich du er sie wir ihr nicht ein eine mit auf zu den dem von hallo danke ja nein bin habe wo was guten gute morgen abend nacht wie geht dir auch aber sehr wiedersehen tschuss hier'.split(' '),
  it: 'il lo la gli le di che e un una non per con sono sei io tu lui lei noi voi ciao grazie dove questo molto bene ho buongiorno buonasera buonanotte arrivederci come stai sto si'.split(' '),
  nl: 'de het een en is ik je jij hij zij we niet van op met voor dat dit hallo dank ja nee waar ben heb wat goedemorgen goedenavond goedenacht doei bedankt hoe gaat'.split(' '),
  pl: 'i w na nie jest to sie ze z do jak co tak czy ja ty on ona my wy dzien dobry dziekuje gdzie jestem mam dobranoc czesc dzieki dziekuje witam'.split(' '),
  tr: 've bir bu da de ne ben sen o biz siz degil var yok merhaba tesekkurler evet hayir nerede nasil cok gunaydin iyi gunler aksamlar selam'.split(' '),
  sv: 'och att det som en ett ar jag du han hon vi ni inte med pa for har hej tack ja nej var god morgon natt hur mar'.split(' '),
  fi: 'ja on ei se en ole mina sina han me te he etta kun mutta hei kiitos kylla missa'.split(' '),
  cs: 'a je to se na v ze s jsem jsi ne ano jak co kde ahoj dekuji dobry den mam'.split(' '),
  ro: 'si este sunt nu da in la cu pe de un o eu tu el ea noi voi buna multumesc unde ce'.split(' '),
  id: 'dan yang di ke dari ini itu saya aku kamu anda dia kami kita tidak ada apa terima kasih halo selamat mau'.split(' '),
  vi: 'va la cua co khong toi ban anh em chung ta cam on xin chao duoc nay day'.split(' '),
};

// Letters that only (or mostly) one Latin-script language uses.
const LETTERS = [
  [/[ñ¿¡]/, 'es', 3], [/[ãõ]/, 'pt', 3], [/ç/, 'pt', 1], [/ç/, 'fr', 1], [/[œèêëîïûù]/, 'fr', 2],
  [/ß/, 'de', 3], [/[äöü]/, 'de', 1], [/[ąęłńśźż]/, 'pl', 3], [/[ğış]/, 'tr', 3], [/[åø]/, 'sv', 2], [/[äö]/, 'sv', 1], [/[äö]/, 'fi', 1],
  [/[ěřůďťň]/, 'cs', 3], [/[șțăî]/, 'ro', 3], [/[ơưđạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹ]/, 'vi', 4],
  [/[àòì]/, 'it', 1],
];

function detect(text) {
  const t = String(text || '');
  if (/[぀-ヿ]/.test(t)) return 'ja';
  if (/[가-힯ᄀ-ᇿ]/.test(t)) return 'ko';
  if (/[一-鿿]/.test(t)) return 'zh';
  if (/[฀-๿]/.test(t)) return 'th';
  if (/[ऀ-ॿ]/.test(t)) return 'hi';
  if (/[؀-ۿ]/.test(t)) return 'ar';
  if (/[Ͱ-Ͽ]/.test(t)) return 'el';
  if (/[Ѐ-ӿ]/.test(t)) return /[іїєґІЇЄҐ]/.test(t) ? 'uk' : 'ru';
  const lower = t.toLowerCase();
  const plain = lower.normalize('NFD').replace(/[̀-ͯ]/g, '');
  const words = plain.match(/[a-z']+/g) || [];
  // Too short to tell (ok, hm, xd): leave it as written.
  if (words.join('').replace(/'/g, '').length < MIN_LETTERS) return 'und';
  const score = {};
  for (const lang in WORDS) {
    let n = 0;
    for (const w of words) if (WORDS[lang].includes(w.replace(/'/g, ''))) n++;
    score[lang] = n;
  }
  for (const [re, lang, weight] of LETTERS) if (re.test(lower)) score[lang] = (score[lang] || 0) + weight;
  let best = 'und';
  let top = 0;
  let second = 0;
  for (const lang in score) {
    if (score[lang] > top) { second = top; top = score[lang]; best = lang; }
    else if (score[lang] > second) second = score[lang];
  }
  // Confidence: a clear winner, and in a line of three or more words more than
  // one hint. One shared short word ("a" in "Ada makes a trench") is not
  // evidence of Portuguese.
  if (top === 0 || top === second) return 'und';
  if (words.length >= 3 && top < 2) return 'und';
  return best;
}

module.exports = { detect, LANGS };
