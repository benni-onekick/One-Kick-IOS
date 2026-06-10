//
//  WmSquads.swift
//  One Kick
//
//  Alle 48 WM 2026-Kader als lokale Daten.
//  Wird für die Spielersuche in Bonus-Tipps (Torschützenkönig, Meiste Vorlagen) verwendet.
//

import Foundation

let wmSquads: [String: [String]] = [
    "Argentinien": [
        "Emiliano Martínez", "Geronimo Rulli", "Juan Musso",
        "Leonardo Balerdi", "Nicolás Tagliafico", "Gonzalo Montiel", "Lisandro Martínez",
        "Cristian Romero", "Nicolás Otamendi", "Facundo Medina", "Nahuel Molina",
        "Leandro Paredes", "Rodrigo De Paul", "Valentín Barco", "Giovani Lo Celso",
        "Exequiel Palacios", "Alexis Mac Allister", "Enzo Fernández",
        "Julián Álvarez", "Lionel Messi", "Nicolás González",
        "Thiago Almada", "Giuliano Simeone", "Nico Paz",
        "José Manuel López", "Lautaro Martínez"
    ],
    "Deutschland": [
        "Manuel Neuer", "Oliver Baumann", "Alexander Nübel",
        "Antonio Rüdiger", "Waldemar Anton", "Jonathan Tah", "Nico Schlotterbeck",
        "Nathaniel Brown", "David Raum", "Malick Thiaw",
        "Aleksandar Pavlović", "Joshua Kimmich", "Leon Goretzka",
        "Jamie Leweling", "Jamal Musiala", "Pascal Groß",
        "Angelo Stiller", "Florian Wirtz", "Leroy Sané",
        "Nadiem Amiri", "Felix Nmecha", "Lennart Käll",
        "Kai Havertz", "Nick Woltemade", "Maximilian Beier", "Deniz Undav"
    ],
    "Frankreich": [
        "Brice Samba", "Mike Maignan", "Robin Risser",
        "Malo Gusto", "Lucas Digne", "Dayot Upamecano", "Jules Koundé",
        "Ibrahima Konaté", "William Saliba", "Theo Hernandez", "Lucas Hernandez",
        "Maxence Lacroix", "Manu Koné", "Aurélien Tchouaméni",
        "N'Golo Kanté", "Adrien Rabiot", "Warren Zaïre-Emery",
        "Ousmane Dembélé", "Marcus Thuram", "Kylian Mbappé",
        "Michael Olise", "Bradley Barcola", "Désiré Doué",
        "Jean-Philippe Mateta", "Rayan Cherki", "Maghnes Akliouche"
    ],
    "Spanien": [
        "David Raya", "Joan García", "Unai Simón",
        "Marc Pubill", "Alejandro Grimaldo", "Eric García", "Marcos Llorente",
        "Pedro Porro", "Aymeric Laporte", "Pau Cubarsí", "Marc Cucurella",
        "Mikel Merino", "Fabián Ruiz", "Gavi",
        "Dani Olmo", "Álex Baena", "Rodri",
        "Martín Zubimendi", "Pedri", "Ferran Torres",
        "Yeremy Pino", "Nico Williams", "Lamine Yamal",
        "Mikel Oyarzabal", "Víctor Muñoz", "Borja Iglesias"
    ],
    "Brasilien": [
        "Alisson", "Ederson", "Weverton",
        "Marquinhos", "Danilo", "Alex Sandro", "Gabriel Magalhães",
        "Bremer", "Wesley", "Roger Ibáñez", "Douglas Santos",
        "Léo Pereira", "Casemiro", "Lucas Paquetá",
        "Bruno Guimarães", "Fabinho", "Danilo Luiz",
        "Neymar", "Vinícius Júnior", "Raphinha",
        "Gabriel Martinelli", "Matheus Cunha", "Endrick",
        "Luiz Henrique", "Igor Thiago", "Rayan"
    ],
    "England": [
        "Jordan Pickford", "Dean Henderson", "James Trafford",
        "Reece James", "Dan Burn", "Marc Guéhi", "Ezri Konsa",
        "Tino Livramento", "Nico O'Reilly", "Jarell Quansah",
        "John Stones", "Djed Spence", "Elliot Anderson",
        "Jude Bellingham", "Jordan Henderson", "Declan Rice",
        "Kobbie Mainoo", "Eberechi Eze", "Anthony Gordon",
        "Noni Madueke", "Morgan Rogers", "Bukayo Saka",
        "Marcus Rashford", "Harry Kane", "Ivan Toney", "Ollie Watkins"
    ],
    "Niederlande": [
        "Mark Flekken", "Robin Röefs", "Bart Verbruggen",
        "Nathan Aké", "Denzel Dumfries", "Jorrel Hato", "Jurriën Timber",
        "Micky van de Ven", "Virgil van Dijk", "Jan Paul van Hecke",
        "Mats Wieffer", "Frenkie de Jong", "Marten de Roon",
        "Ryan Gravenberch", "Justin Kluivert", "Teun Koopmeiners",
        "Tijjani Reijnders", "Guus Til", "Quinten Timber",
        "Brian Brobbey", "Memphis Depay", "Cody Gakpo",
        "Noa Lang", "Donyell Malen", "Crysencio Summerville", "Wout Weghorst"
    ],
    "Portugal": [
        "Diogo Costa", "José Sá", "Rui Silva",
        "Rúben Dias", "João Cancelo", "Nélson Semedo", "Nuno Mendes",
        "Diogo Dalot", "Gonçalo Inácio", "Renato Veiga", "Tomás Araújo",
        "Bernardo Silva", "Bruno Fernandes", "Rúben Neves",
        "Vitinha", "João Neves", "Matheus Nunes",
        "Francisco Trincão", "Samu Costa", "Cristiano Ronaldo",
        "João Félix", "Rafael Leão", "Gonçalo Guedes",
        "Gonçalo Ramos", "Pedro Neto", "Francisco Conceição"
    ],
    "Belgien": [
        "Thibaut Courtois", "Senne Lammens", "Mike Penders",
        "Thomas Meunier", "Timothy Castagne", "Arthur Theate", "Zeno Debast",
        "Maxim De Cuyper", "Brandon Mechele", "Koni De Winter",
        "Joaquin Seys", "Nathan Ngoy", "Axel Witsel",
        "Kevin De Bruyne", "Youri Tielemans", "Hans Vanaken",
        "Amadou Onana", "Nicolas Raskin", "Romelu Lukaku",
        "Leandro Trossard", "Jérémy Doku", "Dodi Lukébakio",
        "Charles De Ketelaere", "Alexis Saelemaekers", "Diego Moreira", "Matías Fernández-Pardo"
    ],
    "Schweiz": [
        "Gregor Kobel", "Yvon Mvogo", "Marvin Keller",
        "Miro Müheim", "Silvan Widmer", "Nico Elvedi", "Manuel Akanji",
        "Ricardo Rodríguez", "Eray Cömert", "Aurèle Amenda",
        "Luca Jaquez", "Denis Zakaria", "Remo Freuler",
        "Johan Manzambi", "Granit Xhaka", "Ardon Jashari",
        "Djibril Sow", "Christian Fassnacht", "Michel Aebischer",
        "Fabian Rieder", "Breel Embolo", "Dan Ndoye",
        "Rubén Vargas", "Noah Okafor", "Zeki Amdouni", "Cédric Itten"
    ],
    "Kroatien": [
        "Dominik Livaković", "Dominik Kotarski", "Ivo Pandur",
        "Joško Gvardiol", "Duje Ćaleta-Car", "Josip Šutalo", "Josip Stanišić",
        "Marin Pongračić", "Martin Erlić", "Luka Vušković",
        "Luka Modrić", "Mateo Kovačić", "Mario Pašalić",
        "Nikola Vlašić", "Luka Sučić", "Martin Baturina",
        "Kristijan Jakić", "Petar Sučić", "Nikola Moro",
        "Toni Fruk", "Ivan Perišić", "Andrej Kramarić",
        "Ante Budimir", "Marco Pašalić", "Petar Muša", "Igor Matanović"
    ],
    "Uruguay": [
        "Fernando Muslera", "Sergio Rochet", "Santiago Mele",
        "José María Giménez", "Matías Viña", "Mathías Olivera", "Guillermo Varela",
        "Ronald Araújo", "Sebastián Cáceres", "Joaquín Piquerez",
        "Santiago Bueno", "Rodrigo Bentancur", "Federico Valverde",
        "Giorgian de Arrascaeta", "Facundo Pellistri", "Manuel Ugarte",
        "Nicolás De La Cruz", "Brian Rodríguez", "Maximiliano Araújo",
        "Agustín Canóbbio", "Emiliano Martínez", "Rodrigo Zalazar",
        "Juan Manuel Sanabria", "Darwin Núñez", "Federico Viñas", "Rodrigo Aguirre"
    ],
    "Kolumbien": [
        "David Ospina", "Camilo Vargas", "Álvaro Montero",
        "Dávinson Sánchez", "Santiago Arias", "Yerry Mina", "Daniel Muñoz",
        "Johan Mojica", "Jhon Lucumí", "Deiver Machado",
        "Willer Ditta", "James Rodríguez", "Jefferson Lerma",
        "Juan Fernando Quintero", "Jhon Arias", "Richard Ríos",
        "Kevin Castaño", "Jorge Carrascal", "Jaminton Campaz",
        "Juan Camilo Portilla", "Gustavo Puerta", "Luis Díaz",
        "Jhon Córdoba", "Luis Suárez", "Cucho Hernández", "Carlos Andrés Gómez"
    ],
    "Ecuador": [
        "Hernán Galíndez", "Moisés Ramírez", "Gonzalo Valle",
        "Félix Torres", "Piero Hincapié", "Joël Ordóñez", "Willian Pacho",
        "Pervis Estupiñán", "Ángelo Preciado", "Jackson Porozo",
        "Denil Castillo", "John Yeboah", "Kendry Páez",
        "Alan Minda", "Pedro Vite", "Gonzalo Plata",
        "Moisés Caicedo", "Yaimar Medina", "Kevin Rodríguez",
        "Enner Valencia", "Anthony Valencia", "Jordy Caicedo",
        "Nilson Angulo", "Jeremy Arévalo"
    ],
    "USA": [
        "Matt Turner", "Matt Freese", "Chris Brady",
        "Sergino Dest", "Chris Richards", "Antonee Robinson", "Auston Trusty",
        "Miles Robinson", "Tim Ream", "Alex Freeman",
        "Max Arfsten", "Mark McKenzie", "Joe Scally",
        "Tyler Adams", "Gio Reyna", "Weston McKennie",
        "Sebastián Berhalter", "Cristian Roldan", "Malik Tillman",
        "Ricardo Pepi", "Christian Pulisic", "Brenden Aaronson",
        "Haji Wright", "Folarin Balogun", "Tim Weah", "Alejandro Zendejas"
    ],
    "Mexiko": [
        "Guillermo Ochoa", "Raúl Rangel", "Carlos Acevedo",
        "Jesús Gallardo", "César Montes", "Jorge Sánchez", "Johan Vásquez",
        "Israel Reyes", "Mateo Chávez", "Edson Álvarez",
        "Orbelín Pineda", "Roberto Alvarado", "Luis Romo",
        "Luis Chávez", "Érik Lira", "Gilberto Mora",
        "Brian Gutiérrez", "Obed Vargas", "Álvaro Fidalgo",
        "Raúl Jiménez", "Alexis Vega", "Santiago Giménez",
        "César Huerta", "Julián Quiñones", "Guillermo Martínez", "Armando González"
    ],
    "Marokko": [
        "Yassine Bounou", "Munir El Kajou", "Ahmed Reda Tagnaouti",
        "Achraf Hakimi", "Noussair Mazraoui", "Nayef Aguerd", "Chadi Riad",
        "Issa Diop", "Anass Salah-Eddine", "Zakaria El Ouahdi",
        "Redouane Halhal", "Youssef Belammari", "Sofyan Amrabat",
        "Azzedine Ounahi", "Neil El Aynaoui", "Bilal El Khannous",
        "Ismaël Saibari", "Samir El Mourabet", "Ayyoub Bouaddi",
        "Gessime Yassine", "Brahim Díaz", "Ayoub El Kaabi",
        "Abde Ezzalzouli", "Soufiane Rahimi", "Chemsdine Talbi", "Ayoub Amaimouni"
    ],
    "Senegal": [
        "Édouard Mendy", "Mory Diaw", "Yehvann Diouf",
        "Kalidou Koulibaly", "Krepin Diatta", "Moussa Niakhité", "Ismail Jakobs",
        "Abdoulaye Seck", "El Hadji Malick Diouf", "Mamadou Sarr",
        "Antoine Mendy", "Idrissa Gueye", "Pape Gueye",
        "Pape Matar Sarr", "Pathe Ciss", "Lamine Camara",
        "Habib Diarra", "Bamba Dieng", "Sadio Mané",
        "Ismaïla Sarr", "Iliman Ndiaye", "Nicolas Jackson",
        "Cherif Ndiaye", "Ibrahim Mbaye", "Assane Diao", "Bara Ndiaye"
    ],
    "Elfenbeinküste": [
        "Yahia Fofana", "Alban Lafont", "Mohamed Koné",
        "Ghislain Konan", "Odilon Kossounou", "Wilfried Singo", "Evan Ndicka",
        "Emmanuel Agbadou", "Guela Doué", "Ousmane Diomandé",
        "Christopher Operi", "Franck Kessié", "Jean Michaël Seri",
        "Ibrahim Sangaré", "Seko Fofana", "Christ Oulai",
        "Parfait Guiagon", "Nicolas Pépé", "Oumar Diakité",
        "Simon Adingra", "Evann Guessand", "Amad Diallo",
        "Yan Diomandé", "Bazouamana Traoré", "Elye Wahi", "Ange-Yoan Bonny"
    ],
    "Ghana": [
        "Lawrence Ati-Zigi", "Benjamin Asare", "Joseph Anang",
        "Abdul Rahman Baba", "Gideon Mensah", "Alidu Seidu", "Jerome Opoku",
        "Jonas Adjetey", "Abdul Mumin", "Kojo Peprah Oppong",
        "Marvin Senaya", "Derrick Luckassen", "Thomas Partey",
        "Abdul Fatawu", "Elisha Owusu", "Caleb Yirenkyi",
        "Kwasi Sibo", "Augustine Boakye", "Jordan Ayew",
        "Antoine Semenyo", "Kamaladeen Sulemana", "Iñaki Williams",
        "Ernest Nuamah", "Christopher Bonsu Baah", "Brandon Thomas-Asante", "Prince Kwabena Adu"
    ],
    "Südafrika": [
        "Ronwen Williams", "Ricardo Goss", "Sipho Chaine",
        "Aubrey Modiba", "Khuliso Mudau", "Nkosinathi Sibisi", "Mbekezeli Mbokazi",
        "Ime Okon", "Samukele Kabini", "Khulumani Ndamane",
        "Thabang Matuludi", "Kamogelo Sebelebele", "Bradley Cross",
        "Olwethu Makhanya", "Teboho Mokoena", "Sphephelo Sithole",
        "Thalente Mbatha", "Jayden Adams", "Themba Zwane",
        "Lyle Foster", "Evidence Makgopa", "Oswin Appollis",
        "Iqraam Rayners", "Relebohile Mofokeng", "Thapelo Maseko", "Tshepang Moremi"
    ],
    "DR Kongo": [
        "Lionel Mpasi", "Timothy Fayulu", "Matthieu Epolo",
        "Chancel Mbemba", "Arthur Masuaku", "Gédéon Kalulu", "Joris Kayembe",
        "Dylan Batubinsika", "Axel Tuanzebe", "Aaron Wan-Bissaka",
        "Steve Kapuadi", "Meschack Elia", "Samuel Moutoussamy",
        "Edo Kayembe", "Théo Bongonda", "Charles Pickel",
        "Gaël Kakuta", "Noah Sadiki", "Nathanaël Mbuku",
        "Aaron Tshibola", "Ngal'ayel Mukau", "Brian Cipenga",
        "Cédric Bakambu", "Fiston Mayele", "Yoane Wissa", "Simon Banza"
    ],
    "Ägypten": [
        "Mohamed El Shenawy", "Mostafa Shobeir", "Mohamed Alaa",
        "El Mahdy Soliman", "Hamdy Fathy", "Ramy Rabia", "Mohamed Hany",
        "Ahmed Abou El Fotouh", "Mohamed Abdelmonem", "Yasser Ibrahim",
        "Hossam Abdelmaguid", "Karim Hafez", "Tarek Alaa",
        "Marwan Attia", "Emam Ashour", "Mohanad Lasheen",
        "Mahmoud Saber", "Nabil Emad", "Mostafa Mohamed",
        "Mohamed Salah", "Trezeguet", "Omar Marmoush",
        "Ibrahim Adel", "Haissem Hassan", "Hamza Abdelkarim", "Zizo"
    ],
    "Algerien": [
        "Luca Zidane", "Oussama Benbot", "Melvin Mästil",
        "Aissa Mandi", "Ramy Bensebaïni", "Mohamed Amine Tougaï", "Rayan Aït-Nouri",
        "Jaouen Hadjam", "Rafik Belghali", "Zineddine Belaïd",
        "Achref Abada", "Samir Chergui", "Nabil Bentaleb",
        "Ramiz Zerrouki", "Hicham Boudaoui", "Farès Chaïbi",
        "Houssem Aouar", "Ibrahim Maza", "Yacine Titraoui",
        "Riyad Mahrez", "Mohamed Amoura", "Amine Gouiri",
        "Anis Hadj Moussa", "Adil Boulbina", "Nadhir Benbouali", "Farès Ghedjemis"
    ],
    "Tunesien": [
        "Aymen Dahmen", "Sabri Ben Heesen", "Mouhib Chamakh",
        "Montassar Talbi", "Dylan Bronn", "Ali Abdi", "Yan Valery",
        "Mohamed Amine Ben Hamida", "Moutas Neffati", "Omar Rekik",
        "Adem Arous", "Raed Chikhaoui", "Ellyes Skhiri",
        "Hannibal Mejbri", "Anis Ben Slimane", "Mortadha Ben Ouanes",
        "Ismail Gharbi", "Hadj Mahmoud", "Rani Khedira",
        "Elias Achouri", "Firas Chaouat", "Hazem Mastouri",
        "Elias Saad", "Sebastien Tounekti", "Khalil Ayari", "Rayan Elloumi"
    ],
    "Kap Verde": [
        "Vozinha", "Marcio Rosa", "CJ Dos Santos",
        "Stopira", "Roberto Lopes", "João Paulo", "Diney",
        "Logan Costa", "Steven Moreira", "Wagner Pina",
        "Sidny Lopes Cabral", "Kelvin Pires", "Jamiro Monteiro",
        "Kevin Pina", "Deroy Duarte", "Telmo Arcanjo",
        "Laros Duarte", "Yannick Semedo", "Ryan Mendes",
        "Garry Rodrigues", "Willy Semedo", "Jovane Cabral",
        "Gilson Tavares", "Dailon Livramento", "Helio Varela", "Nuno Da Costa"
    ],
    "Japan": [
        "Zion Suzuki", "Keisuke Osako", "Tomoki Hayakawa",
        "Yukinari Sugawara", "Shogo Taniguchi", "Ko Itakura", "Yuta Nagatomo",
        "Tsuyoshi Watanabe", "Ayumu Seko", "Hiroki Ito",
        "Takehiro Tomiyasu", "Junnosuke Suzuki", "Wataru Endo",
        "Ao Tanaka", "Takefusa Kubo", "Ritsu Doan",
        "Keito Nakamura", "Junya Ito", "Daichi Kamada",
        "Kaishu Sano", "Keisuke Goto", "Daizen Maeda",
        "Yuito Suzuki", "Ayase Ueda", "Koki Ogawa", "Kento Shiogai"
    ],
    "Südkorea": [
        "Kim Seung-gyu", "Jo Hyeon-woo", "Song Bum-keun",
        "Kim Min-jae", "Kim Moon-hwan", "Seol Young-woo", "Lee Tae-seok",
        "Park Jin-seob", "Kim Tae-hyeon", "Lee Han-beom",
        "Jens Castrop", "Lee Ki-hyuk", "Cho Wi-je",
        "Lee Jae-sung", "Hwang Hee-chan", "Hwang In-beom",
        "Lee Kang-in", "Paik Seung-ho", "Kim Jin-gyu",
        "Lee Dong-gyeong", "Bae Jun-ho", "Eom Ji-sung",
        "Yang Hyun-jun", "Son Heung-min", "Cho Gue-sung", "Oh Hyeon-gyu"
    ],
    "Australien": [
        "Mathew Ryan", "Paul Izzo", "Patrick Beach",
        "Milos Degenek", "Alessandro Circati", "Jacob Italiano", "Jordan Bos",
        "Jason Geria", "Kai Trewin", "Aziz Behich",
        "Harry Souttar", "Cameron Burgess", "Lucas Herrington",
        "Connor Metcalfe", "Ajdin Hrustic", "Aiden O'Neill",
        "Cameron Devlin", "Jackson Irvine", "Paul Okon-Engstler",
        "Mathew Leckie", "Mohamed Toure", "Awer Mabil",
        "Nestory Irankunda", "Cristian Volpato", "Nishan Velupillay", "Tete Yengi"
    ],
    "Neuseeland": [
        "Max Crocombe", "Alex Paulsen", "Michael Woud",
        "Tim Payne", "Francis De Vries", "Tyler Bindon", "Michael Boxall",
        "Liberato Cacace", "Nando Pijnaker", "Finn Surman",
        "Callan Elliot", "Tommy Smith", "Joe Bell",
        "Marko Stamenić", "Alex Rufer", "Ryan Thomas",
        "Lachlan Bayliss", "Matt Garbett", "Chris Wood",
        "Sarpreet Singh", "Eli Just", "Kosta Barbarouses",
        "Ben Waine", "Ben Old", "Callum McCowatt", "Jesse Randall"
    ],
    "Kanada": [
        "Dayne St. Clair", "Maxime Crépeau", "Owen Goodman",
        "Alistair Johnston", "Luc De Fougerolles", "Alfie Jones", "Joel Waterman",
        "Derek Cornelius", "Moïse Bombito", "Alphonso Davies",
        "Richie Laryea", "Niko Sigur", "Mathieu Choinière",
        "Stephen Eustáquio", "Ismaël Koné", "Liam Millar",
        "Jacob Shaffelburg", "Tajon Buchanan", "Ali Ahmed",
        "Jonathan Osorio", "Nathan Saliba", "Marcelo Flores",
        "Cyle Larin", "Jonathan David", "Tani Oluwaseyi", "Promise David"
    ],
    "Norwegen": [
        "Ørjan Nyland", "Sander Tangvik", "Egil Selvik",
        "Kristoffer Ajer", "Leo Østigård", "David Møller Wolfe", "Fredrik André Bjørkan",
        "Marcus Holmgren Pedersen", "Torbjørn Heggem", "Sondre Langås",
        "Henrik Falchener", "Julian Ryerson", "Morten Thorsby",
        "Patrick Berg", "Sander Berge", "Martin Ødegaard",
        "Fredrik Aursnes", "Kristian Thorstvedt", "Thelo Aasgaard",
        "Antonio Nusa", "Andreas Schjelderup", "Oscar Bobb",
        "Jens Petter Hauge", "Alexander Sørloth", "Erling Haaland", "Jørgen Strand Larsen"
    ],
    "Schweden": [
        "Jacob Widell Zetterstrom", "Viktor Johansson", "Kristoffer Nordfeldt",
        "Gustaf Lagerbielke", "Victor Nilsson Lindelöf", "Isak Hien", "Gabriel Gudmundsson",
        "Herman Johansson", "Daniel Svensson", "Hjalmar Ekdal",
        "Carl Starfelt", "Eric Smith", "Elliot Stroud",
        "Lucas Bergvall", "Ken Sema", "Jesper Karlström",
        "Yasin Ayari", "Mattias Svanberg", "Besfort Zeneli",
        "Taha Ali", "Alexander Isak", "Benjamin Nygren",
        "Anthony Elanga", "Viktor Gyökeres", "Alexander Bernhardsson", "Gustaf Nilsson"
    ],
    "Österreich": [
        "Alexander Schlager", "Florian Wiegele", "Patrick Pentz",
        "Dafid Affengruber", "Kevin Danso", "Stefan Posch", "David Alaba",
        "Philipp Lienhart", "Philipp Mwene", "Alexander Prass",
        "Marco Friedl", "Michael Svoboda", "Xaver Schlager",
        "Nicolas Seiwald", "Marcel Sabitzer", "Florian Grillitsch",
        "Carney Chukwuemeka", "Romano Schmid", "Christoph Baumgartner",
        "Konrad Laimer", "Patrick Wimmer", "Paul Wanner",
        "Alessandro Schöpf", "Marko Arnautović", "Michael Gregoritsch", "Sasa Kalajdzic"
    ],
    "Tschechien": [
        "Matěj Kovář", "Jindřich Staněk", "Lukáš Horníček",
        "Vladimír Coufal", "Tomáš Holeš", "Ladislav Krejčí", "David Zima",
        "Jaroslav Zelený", "David Jurásek", "David Douděra",
        "Robin Hranáč", "Štěpán Chaloupek", "Tomáš Souček",
        "Vladimír Darida", "Lukáš Provod", "Michal Sadílek",
        "Pavel Šulc", "Lukáš Červ", "Hugo Sochůrek",
        "Alexandr Sojka", "Denis Višinský", "Patrik Schick",
        "Adam Hložek", "Jan Kuchta", "Tomáš Chorý", "Mojmír Chytil"
    ],
    "Schottland": [
        "Craig Gordon", "Angus Gunn", "Liam Kelly",
        "Grant Hanley", "Jack Hendry", "Aaron Hickey", "Dom Hyam",
        "Scott McKenna", "Nathan Patterson", "Anthony Ralston",
        "Andy Robertson", "John Souttar", "Kieran Tierney",
        "Ryan Christie", "Findlay Curtis", "Lewis Ferguson",
        "Ben Doak", "John McGinn", "Kenny McLean",
        "Scott McTominay", "Tyler Fletcher", "Che Adams",
        "Lyndon Dykes", "George Hirst", "Lawrence Shankland", "Ross Stewart"
    ],
    "Türkei": [
        "Uğurcan Çakır", "Mert Günok", "Altay Bayındır",
        "Merih Demiral", "Zeki Çelik", "Çağlar Söyüncü", "Mert Müldür",
        "Ferdi Kadıoğlu", "Ozan Kabak", "Abdülkerim Bardakcı",
        "Eren Elmalı", "Sema Akaydin", "Ahmetcan Kaplan",
        "Hakan Çalhanoğlu", "Kaan Ayhan", "Orkun Kökçü",
        "İsmail Yüksek", "Salih Özcan", "Atakan Karazor",
        "Kerem Aktürkoğlu", "Baris Alper Yilmaz", "Arda Güler",
        "Kenan Yıldız", "Yunus Akgün", "Can Uzun", "Yusuf Sarı"
    ],
    "Saudi-Arabien": [
        "Mohammed Al-Owais", "Nawaf Al-Aqidi", "Ahmed Al-Kasser",
        "Saud Abdulhamid", "Hassan Al-Tambakti", "Abdulelah Al-Amri", "Nawaf Boushal",
        "Ali Majrashi", "Ali Lajami", "Hassan Kadesh",
        "Moteb Al-Harbi", "Jehad Thakri", "Mohammed Abu Al-Shamat",
        "Salem Al-Dawsari", "Mohamed Kanno", "Nasser Al-Dawsari",
        "Abdullah Al-Khaibari", "Musab Al-Juwayr", "Ayman Yahya",
        "Ziyad Al-Johani", "Sultan Mandash", "Alla Al-Heiji",
        "Firas Al-Buraikan", "Saleh Al-Shehri", "Abdullah Al-Hamdan", "Khalid Al-Ghannam"
    ],
    "Iran": [
        "Alireza Beiranvand", "Payam Niazmand", "Hossein Hosseini",
        "Ehsan Hajsafi", "Milad Mohammadi", "Ramin Rezaeian", "Hossein Kanaanizadegan",
        "Shojae Khalilzadeh", "Saleh Hardani", "Ali Nemati",
        "Danial Eiri", "Alireza Jahanbakhsh", "Saeid Ezatolahi",
        "Saman Ghoddos", "Mahdi Torabi", "Rouzbeh Cheshmi",
        "Mohammad Mohebi", "Mehdi Ghayedi", "Mohammad Ghorbani",
        "Aria Yousefi", "Amirmohammad Rassaghinia", "Mehdi Taremi",
        "Shahriyar Moghanlou", "Amirhossein Hosseinzadeh", "Ali Alipour", "Dennis Eckert"
    ],
    "Irak": [
        "Jalal Hassan", "Fahad Talib", "Ahmed Basil",
        "Rebin Sulaka", "Manaf Younis", "Merchas Doski", "Hussein Ali",
        "Zaid Tahseen", "Frans Putros", "Ahmed Yahya",
        "Mustafa Saadoon", "Akam Hashim", "Ibrahim Bayesh",
        "Amir Al-Ammari", "Ali Jasim", "Youssef Amyn",
        "Zidane Iqbal", "Marko Farji", "Kevin Yakob",
        "Aimar Sher", "Zaid Ismail", "Ahmed Qasem",
        "Aymen Hussein", "Mohanad Ali", "Ali Al-Hamadi", "Ali Yousuf"
    ],
    "Jordanien": [
        "Yazeed Abdulaila", "Abdallah Al-Fakhouri", "Nour Bani Attiah",
        "Ihsan Haddad", "Yazan Al-Arab", "Abdallah Nasib", "Saed Al-Rosan",
        "Husam Abu Dahab", "Mohammad Abualnadi", "Salim Obaid",
        "Anas Badawi", "Rajaei Ayed", "Noor Al-Rawabdeh",
        "Ibrahim Sa'deh", "Mohammad Abu Hashish", "Nizar Al-Rashdan",
        "Mohannad Abu Taha", "Amer Jamous", "Mohammad Al-Dawoud",
        "Yousef Qashi", "Musa Al-Taamari", "Ali Olwan",
        "Mohammad Abu Zrayq", "Ibrahim Sabra", "Ali Azaizeh", "Odeh Al-Fakhouri"
    ],
    "Katar": [
        "Mahmoud Abunada", "Salah Zakaria", "Meshaal Barsham",
        "Pedro Miguel", "Lucas Mendes", "Issa Laye", "Ayoub Al-Oui",
        "Homam Ahmed", "Boualem Khoukhi", "Sultan Al-Brake",
        "Al-Hashmi Al-Hussain", "Jassem Gaber", "Abdulaziz Hatem",
        "Karim Boudiaf", "Ahmed Fathy", "Assim Madibo",
        "Mohamed Al-Mannai", "Ahmed Alaaeldin", "Edmilson Junior",
        "Mohammed Muntari", "Hassan Al-Haydos", "Akram Afif",
        "Yusuf Abdurisag", "Ahmed Al-Ganehi", "Almoez Ali", "Tahsin Jamshid"
    ],
    "Paraguay": [
        "Gatito Fernández", "Orlando Gill", "Gastón Olveira",
        "Gustavo Gómez", "Junior Alonso", "Fabián Balbuena", "Omar Alderete",
        "Juan Cáceres", "Gustavo Velázquez", "José Cañale",
        "Alexandro Maidana", "Miguel Almirón", "Kaku",
        "Ramón Sosa", "Andrés Cubas", "Diego Gómez",
        "Damián Bobadilla", "Braian Ojeda", "Matías Galarza",
        "Mauricio Isla", "Antonio Sanabria", "Julio Enciso",
        "Gabriel Ávalos", "Alex Arce", "Isidro Pitta", "Gustavo Caballero"
    ],
    "Panama": [
        "Luis Mejía", "Orlando Mosquera", "César Samudio",
        "Eric Davis", "Fidel Escobar", "Michael Amir Murillo", "Roderick Miller",
        "Andrés Andrade", "César Blackman", "José Córdoba",
        "Jiovany Ramos", "Jorge Gutiérrez", "Edgardo Farina",
        "Aníbal Godoy", "Alberto Quintero", "Yoel Bárcenas",
        "Adalberto Carrasquilla", "José Luis Rodríguez", "Cristian Martínez",
        "César Yanis", "Carlos Harvey", "Azarías Londoño",
        "José Fajardo", "Ismael Díaz", "Cecilio Waterman", "Tomás Rodríguez"
    ],
    "Haiti": [
        "Johny Placide", "Alexandre Pierre", "Josué Duverger",
        "Ricardo Adé", "Carlens Arcus", "Martin Experience", "Jean-Kevin Duverne",
        "Duke Lacroix", "Wilguens Paugain", "Hannes Delcroix",
        "Keeto Thermoncy", "Leverton Pierre", "Danle Jean Jacques",
        "Carl Sainte", "Jean-Ricner Bellegarde", "Woodensky Pierre",
        "Dominique Simon", "Duckens Nazon", "Frantzdy Pierrot",
        "Derrick Etienne Jr.", "Louicius Deedson", "Ruben Providence",
        "Josué Casimir", "Yassin Fortune", "Wilson Isidor", "Lenny Joseph"
    ],
    "Bosnien": [
        "Nikola Vasilj", "Martin Zlomislić", "Osman Hadžikić",
        "Sead Kolašinac", "Amar Dedić", "Nihad Mujakić", "Nikola Katić",
        "Tarik Muharemović", "Stjepan Radeljić", "Dennis Hadžikadunić",
        "Nidal Čelik", "Amir Hadžiahmetović", "Ivan Šunjić",
        "Ivan Bašić", "Dženis Burnić", "Ermin Mahmić",
        "Benjamin Tahirović", "Amar Memić", "Armin Gigović",
        "Kerim Alajbegović", "Esmir Bajraktarević", "Ermedin Demirović",
        "Jovo Lukić", "Samed Baždar", "Haris Tabaković", "Edin Džeko"
    ],
    "Curaçao": [
        "Eloy Room", "Tyrick Bodak", "Trevor Doornbusch",
        "Shurandy Sambo", "Jurien Gaari", "Roshon van Ejima", "Sherel Floranus",
        "Armando Obispo", "Joshua Brenet", "Riechedly Bazoer",
        "Deveron Fonville", "Godfried Roemeratoe", "Juninho Bacuna",
        "Livano Comenencia", "Leandro Bacuna", "Tyrese Noslin",
        "Ar'jany Martha", "Kevin Felida", "Jürgen Locadia",
        "Jeremy Antonisse", "Sontje Hansen", "Kenji Gorré",
        "Jearl Margaritha", "Brandley Kuwas", "Gervane Kastaneer", "Tahith Chong"
    ],
    "Usbekistan": [
        "Utkir Yusupov", "Botirali Ergashev", "Abduvohid Nematov",
        "Rustam Ashurmatov", "Farrukh Sayfiev", "Khojiakbar Alijonov", "Sherzod Nasrullaev",
        "Umar Eshmurodov", "Abdukodir Khusanov", "Abdulla Abdullaev",
        "Bekhruz Karimov", "Jakhongir Urozov", "Avazbek Ulmasaliev",
        "Otabek Shukurov", "Odiljon Khamrobekov", "Jamshid Iskanderov",
        "Akmal Mozgovoy", "Azizjon Ganiev", "Jasurbek Jaloliddinov",
        "Umarali Rakhmonaliev", "Sherzod Esanov", "Eldor Shomurodov",
        "Igor Sergeev", "Jaloliddin Masharipov", "Oston Urunov", "Abbosbek Fayzullaev"
    ]
]

// Flache, alphabetisch sortierte Liste aller WM-Spieler für die Suche
let wmAllPlayerNames: [String] = wmSquads.values.flatMap { $0 }.sorted()

// FIFA WM 2026 Gruppen (A–L) – Reihenfolge der Teams innerhalb der Gruppe = beliebig (nicht Endplatzierung)
// Quelle: FIFA-Auslosung vom 05.12.2024 in Miami
// ⚠️ Bitte die genauen Gruppen-Zuordnungen anhand der offiziellen Auslosung prüfen/korrigieren.
let wmGroupNames: [String] = [
    "Gruppe A", "Gruppe B", "Gruppe C", "Gruppe D",
    "Gruppe E", "Gruppe F", "Gruppe G", "Gruppe H",
    "Gruppe I", "Gruppe J", "Gruppe K", "Gruppe L"
]

let wmGroups: [String: [String]] = [
    "Gruppe A": ["USA", "Panama", "Uruguay", "Kap Verde"],
    "Gruppe B": ["Mexiko", "Ecuador", "Niederlande", "Irak"],
    "Gruppe C": ["Kanada", "Kolumbien", "Deutschland", "Neuseeland"],
    "Gruppe D": ["Argentinien", "Chile", "Frankreich", "Jordanien"],
    "Gruppe E": ["Brasilien", "Paraguay", "Spanien", "Katar"],
    "Gruppe F": ["England", "Senegal", "Schweiz", "DR Kongo"],
    "Gruppe G": ["Portugal", "Uruguay", "Marokko", "Japan"],
    "Gruppe H": ["Belgien", "Kroatien", "Südkorea", "Tunesien"],
    "Gruppe I": ["Türkei", "Ghana", "Iran", "Schottland"],
    "Gruppe J": ["Österreich", "Elfenbeinküste", "Australien", "Ägypten"],
    "Gruppe K": ["Schweden", "Algerien", "Südafrika", "Usbekistan"],
    "Gruppe L": ["Norwegen", "Tschechien", "Bosnien", "Südkorea"]
]
// ☝️ Obige Gruppen sind Platzhalter – bitte mit den tatsächlichen FIFA-Auslosungsgruppen ersetzen!
