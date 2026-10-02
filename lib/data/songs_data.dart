// 1000 Songs - 500 Hindi + 500 Punjabi - No Bug Version

const List<String> baseHindi100 = [
  "Tum Hi Ho", "Kesariya", "Gerua", "Raabta", "Channa Mereya",
  "Ae Dil Hai Mushkil", "Kabira", "Kal Ho Naa Ho", "Tum Se Hi", "Kun Faya Kun",
  "Chaiyya Chaiyya", "Senorita", "Badtameez Dil", "Kala Chashma", "Nashe Si Chadh Gayi",
  "Balam Pichkari", "Ghagra", "Ainvayi Ainvayi", "Subah Hone Na De", "Brown Munde Hindi",
  "Bol Do Na Zara", "Samjhawan", "Sanam Re", "Lo Safar", "Phir Bhi Tumko Chaahunga",
  "Zaalima", "Humsafar", "Tera Ban Jaunga", "Bekhayali", "Dil Diyan Gallan",
  "Malang", "Shayad", "Khairiyat", "Tujhe Kitna Chahne Lage", "Baarish", "Vaaste",
  "Filhaal", "Leja Re", "Dil Mein Ho Tum", "Pachtaoge", "Tera Yaar Hoon Main",
  "Ghungroo", "Malhari", "Deva Shree Ganesha", "Aankh Marey", "Dilbar", "O Saki Saki",
  "Garmi", "Muqabla", "Param Sundari", "Chaka Chak", "Nagada Sang Dhol", "Dholida",
  "Bole Chudiyan", "Mehendi Laga Ke Rakhna", "Tujh Mein Rab Dikhta Hai", "Maahi Ve", "Sajdaa",
  "Masakali", "Saddi Gali", "Sawaar Loon", "Radha", "Manwa Laage", "Deewani Mastani",
  "Pinga", "Mohe Rang Do Laal", "Ghoomar", "Pal Pal Dil Ke Paas", "Pehla Nasha",
  "Ek Pal Ka Jeena", "Kaho Naa Pyaar Hai", "Mitwa", "Suraj Hua Maddham", "Lungi Dance",
  "Jhoome Jo Pathaan", "Chaleya", "Zinda Banda", "What Jhumka", "O Maahi", "Heeriye",
  "Mahiye Jinna Sohna", "Maan Meri Jaan", "Manike", "Ranjha", "Raatan Lambiyan",
  "Rait Zara Si", "Srivalli", "Oo Antava", "Saami Saami", "Dhol Bajaa", "Apna Bana Le",
  "Tere Naal", "Makhna", "Laung Laachi", "Morni Banke", "Bom Diggy", "High Rated Gabru",
  "Patola", "Lahore", "Naah", "Prada"
];

const List<String> basePunjabi100 = [
  "Brown Munde", "295", "Levels", "Excuses", "Insane", "Daku", "We Rollin", "Afsos", "Same Beef", "GOAT",
  "Legend", "Bambiha Bole", "Old Skool", "Majhail", "Clash", "Patiala Peg", "Morni Banke Punjabi", "High Rated Gabru Punjabi", "Suit", "Prada Punjabi",
  "Do You Know", "Naah", "Khat", "Qismat", "Mann Bharya", "Filhaal Punjabi", "Lehenga", "Butterfly", "Horn Blow", "Wang Da Naap",
  "Angreji Wali Madam", "Dairy", "Chitta Kurta", "Jatt Da Muqabla", "Diamond", "Guilty", "Guitar", "8 Parche", "Paagla", "Sakhiyan",
  "Coka", "Aja Sohneya", "Shopping", "Gallan Kardi", "Kali Jotta", "Meri Aashiqui", "Titliaan", "Sohnea", "Jhanjar", "Chauffeur",
  "Mexico", "Waalian", "Bijlee Bijlee", "Bachke Bachke", "Na Ji Na", "Jug Jug Jeeve", "Chandra", "Kina Chir", "Bamb Jatt", "Jatt Di Clip",
  "Chitta Kurta 2", "Chal Meri Jaan", "Badnam", "Dabde Ni", "Challa", "Angreji", "Yaar Mod Do", "Daru Badnaam", "Yaar Anmulle", "Koka",
  "Gulab", "Kangani", "Haye Tauba", "Chal Ve", "Jhanjran", "Nattiyan", "Chitta", "Saare Bolde", "Dekh De", "Jhanjra",
  "Kala Tikka", "Koka Kola", "Kalaastar", "Chorni", "Zindagi", "Mushkil", "Waddi Gal", "Kali Hoodie", "Black Suit", "Chandra AP",
  "Dheere Dheere", "Ik Mili Mainu Apsraa", "Kala Joda", "Laal Pari", "Suit Patiala", "Jatt Zimidar", "Jatti", "Gaddi Pichhe Naa", "Jatti Di Clip", "Jhanjar Punjabi"
];

// Yeh final 1000 list hai - bug free
final List<String> allSongs1000 = [
  ...List.generate(500, (i) {
    String base = baseHindi100[i % baseHindi100.length];
    int vol = i ~/ baseHindi100.length + 1;
    return vol == 1 ? base : "$base $vol";
  }),
  ...List.generate(500, (i) {
    String base = basePunjabi100[i % basePunjabi100.length];
    int vol = i ~/ basePunjabi100.length + 1;
    return vol == 1 ? base : "$base $vol";
  }),
];

final List<String> hindiSongs500 = List.generate(500, (i) {
  String base = baseHindi100[i % baseHindi100.length];
  int vol = i ~/ baseHindi100.length + 1;
  return vol == 1 ? base : "$base $vol";
});

final List<String> punjabiSongs500 = List.generate(500, (i) {
  String base = basePunjabi100[i % basePunjabi100.length];
  int vol = i ~/ basePunjabi100.length + 1;
  return vol == 1 ? base : "$base $vol";
});