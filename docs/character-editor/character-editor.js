/**
 * MOJAxMOJA WARS - Web Character Editor Main Engine
 */

(function(window) {
  'use strict';

  const {
    NES_MASTER_PALETTE,
    quantizeImageToNesSubpalette,
    decomposeIntoMetaSprites,
    analyzeScanlineDensity,
    tile8x8ToNesChr,
    formatChrAsAssembly,
    autoDownscalePixelArt
  } = window.SpriteProcessor;

  // =============================================================================
  // Built-in Default Character Presets (Official MOJAxMOJA WARS Artwork)
  // =============================================================================

  function createDefaultSubpalettes() {
    return [
      // Subpalette 0: Player (White 3, Cobalt Blue 1, Red 2)
      [0x0f, 0x12, 0x16, 0x20],
      // Subpalette 1: Rival Boss (Crimson 2, Dark Red 1, White/Antenna 3)
      [0x0f, 0x06, 0x16, 0x20],
      // Subpalette 2: Mass-Production (Green 2, Dark Green 1, Monoeye Red/White 3)
      [0x0f, 0x0a, 0x1a, 0x16],
      // Subpalette 3: Ally Transport (Blue 1, Red 2, Gold/Orange 3)
      [0x0f, 0x11, 0x16, 0x27],
    ];
  }

  function parseRowsToFrame(rows, width, height, duration = 10) {
    const indexedPixels = new Uint8Array(width * height);
    for (let y = 0; y < height; y++) {
      const row = rows[y] || "";
      for (let x = 0; x < width; x++) {
        const ch = row[x] || '.';
        let val = 0;
        if (ch === '1') val = 1;
        else if (ch === '2') val = 2;
        else if (ch === '3') val = 3;
        indexedPixels[y * width + x] = val;
      }
    }
    const meta = decomposeIntoMetaSprites(width, height, indexedPixels);
    return {
      duration,
      width,
      height,
      tiles: meta.deduplicatedTiles,
      sprites: meta.spriteInstances,
      hurtbox: { x: 2, y: 2, w: width - 4, h: height - 4 },
      hitbox: { x: 4, y: 4, w: Math.max(4, width - 8), h: Math.max(4, height - 8) }
    };
  }

  // =============================================================================
  // Full MOJAxMOJA WARS Character Roster (All 22 In-Game Assets)
  // =============================================================================

  const PLAYER_CORE_ROWS_1 = [
    ".......33.......",
    "......3113......",
    "......3113......",
    ".....332233.....",
    ".....323323.....",
    "....33233233....",
    "...1332222331...",
    "..113332233311..",
    ".11333122133311.",
    "1133311221133311",
    "333221.33.122333",
    "33.22..33..22.33",
    "3.....2332.....3",
    "......2..2......",
    ".....2....2.....",
    "................",
  ];

  const PLAYER_CORE_ROWS_2 = [
    ".......33.......",
    "......3113......",
    "......3113......",
    ".....332233.....",
    ".....323323.....",
    "....33233233....",
    "...1332222331...",
    "..113332233311..",
    ".11333122133311.",
    "1133311221133311",
    "333221.33.122333",
    "33.22..33..22.33",
    "3.....2332.....3",
    ".....23..32.....",
    ".....3....3.....",
    ".....2....2.....",
  ];

  const PLAYER_FORM2_ROWS = [
    ".......33.......",
    "......3113......",
    ".....332233.....",
    "....33233233....",
    "..113323323311..",
    ".11333222233311.",
    "1133311221133311",
    "3332211331122333",
    ".3322.2332.2233.",
    "....11322311....",
    "...1133223311...",
    "...3331..1333...",
    "...3331..1333...",
    "..33233..33233..",
    "..33233..33233..",
    "..33333..33333..",
    "..33133..33133..",
    "..33133..33133..",
    "..33333..33333..",
    "..22222..22222..",
    ".223322..223322.",
    ".222222..222222.",
    "..2..2....2..2..",
    "................",
  ];

  const PLAYER_FORM2_5_ROWS = [
    "..33...22...33..",
    "...33.3223.33...",
    "....33333333....",
    "....31333313....",
    "....33322333....",
    ".33311122111333.",
    "3323113333113233",
    "3333112222113333",
    "3311111221111133",
    "3311.112211.1133",
    ".22..332233..22.",
    ".....132231.....",
    "....13322331....",
    "...1133223311...",
    "..113312213311..",
    ".11331133113311.",
    "1133311331133311",
    "3322331331332233",
    "2222233223322222",
    "....33122133....",
    "....31.22.13....",
    "....2..22..2....",
    ".......22.......",
    "................",
  ];

  const PLAYER_MS_ROWS = [
    ".....33...22...33....11.",
    "......33.3223.33....131.",
    ".......33333333.....121.",
    ".......31331333....1131.",
    "..222..3332233....11311.",
    ".23332.333333333.113311.",
    "2322232331112213311311..",
    "232323211112221133131...",
    "2323232.1133221133111...",
    "2323232.11122111.3311...",
    "2322232..332233..33211..",
    ".23332..33311333..1111..",
    "..222..3332332333..11...",
    "......33311..11333......",
    ".....33333....33333.....",
    "....33233......33233....",
    "....33233......33233....",
    "...333133......333333...",
    "...33113.......331133...",
    "..222222.......331133...",
    ".223322........333333...",
    ".222222........2222222..",
    "...............2233322..",
    "...............2222222..",
  ];

  const PART_LEG_ROWS = [
    "....11322311....",
    "...1133223311...",
    "..333112211333..",
    "..3331....1333..",
    "..33233..33233..",
    "..33233..33233..",
    "..33333..33333..",
    "..33133..33133..",
    "..33133..33133..",
    "..33333..33333..",
    "..33333..33333..",
    "..22222..22222..",
    ".223322..223322.",
    ".223322..223322.",
    ".222222..222222.",
    "................",
  ];

  const PART_CHEST_ROWS = [
    "..33...22...33..",
    "...33.3223.33...",
    "....33333333....",
    "....31333313....",
    "....33322333....",
    ".33311122111333.",
    "3323113333113233",
    "3333112222113333",
    "3311111221111133",
    "3311.112211.1133",
    "331..332233..133",
    ".22..331133..22.",
    "......2332......",
    "......2222......",
    "................",
    "................",
  ];

  const ALLY_CARRIER_ROWS = [
    "..33..2222..33..",
    ".3113.2332.3113.",
    "3133132332313313",
    "3133132222313313",
    ".31131333313113.",
    "..331132231133..",
    ".22223322332222.",
    "2333332332333332",
    "2333332332333332",
    ".22223322332222.",
    "....11333311....",
    "....13322331....",
    ".....32..23.....",
    ".....2....2.....",
    "................",
    "................",
  ];

  const ENEMY_SCOUT_ROWS = [
    "..1..........1..",
    ".131...11...131.",
    ".131..1331..131.",
    ".111.113311.111.",
    ".11111111111111.",
    ".11331133113311.",
    ".11331133113311.",
    ".11111111111111.",
    ".131.113311.131.",
    ".131..1111..131.",
    ".111..1..1..111.",
    "..1...3..3...1..",
    "......1..1......",
    "................",
    "................",
    "................",
  ];

  const ENEMY_UFO_ROWS = [
    ".....133331.....",
    "....13311331....",
    "...1311331131...",
    "..111111111111..",
    ".11331133113311.",
    "1331133113311331",
    "1111111111111111",
    ".11111111111111.",
    "...1113113111...",
    "....1..11..1....",
    "...3........3...",
    "................",
    "................",
    "................",
    "................",
    "................",
  ];

  const ENEMY_LANCE_ROWS = [
    "..3..........3..",
    ".313...11...313.",
    ".111..1331..111.",
    ".11111311311111.",
    ".11311311311311.",
    "..113113311311..",
    "..111331133111..",
    "...1111111111...",
    "....11311311....",
    "....11333311....",
    ".....13..31.....",
    "......3..3......",
    "......1..1......",
    "................",
    "................",
    "................",
  ];

  const ENEMY_GUNSHIP_ROWS = [
    "...1111331111...",
    "..113333333311..",
    ".11311111111311.",
    "1131111331111311",
    "1131111331111311",
    "1311331111331131",
    "1311111331111131",
    ".11311133111311.",
    ".11111111111111.",
    "..131.1..1.131..",
    "..131.3..3.131..",
    "...3..1..1..3...",
    "................",
    "................",
    "................",
    "................",
  ];

  const MIDBOSS_ZAKU_ROWS = [
    ".........33.............",
    "........3223............",
    ".......122221...........",
    "......12222221..........",
    ".....1111111111....1....",
    ".....1133111111...121...",
    "....122221222221.12321..",
    "....1122222222111223221.",
    "..33.1112222111223323221",
    ".31131221111221232222321",
    "311111122222211222112221",
    "31111111233211112222221.",
    ".....1112332111.112211..",
    "......12222221...1221...",
    ".....1222112221..1221...",
    "....122211112221.1221...",
    "...122221..1222211111...",
    "...12221....12221.......",
    "..123321....123321......",
    "..123321....123321......",
    "..122221....122221......",
    ".12211221..12211221.....",
    ".12211221..12211221.....",
    ".12222221..12222221.....",
    "113333331..113333331....",
    "111111111..111111111....",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
  ];

  const MIDBOSS_DOM_ROWS = [
    "........122221..........",
    ".......12233221.........",
    "......1211331121........",
    "...333111333311133333...",
    "..31111111331111111113..",
    ".3113331222222122332213.",
    ".3111112233332223333323.",
    "..333.12232232222322322.",
    "......12233332212233221.",
    ".....12211111122112211..",
    "....12221233212221......",
    "...1222212332122221.....",
    "..122332211112233221....",
    ".12233332222223333221...",
    ".12221111222211112221...",
    "12221....1111....12221..",
    "122221..122221..122221..",
    ".11111..123321..123321..",
    ".......1223322112233221.",
    "......122233222222332221",
    ".....1222111122221111222",
    "....12233222232122223322",
    "...122333333332133333332",
    "...111111111111.11111111",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
  ];

  const MIDBOSS_ZGOK_ROWS = [
    ".......11222211.........",
    ".....112233332211.......",
    "....12233111133221......",
    "...1233111331113321.....",
    "..123311133331113321....",
    ".12332221133112223321...",
    "33122333222222333221....",
    ".33122322111122322122...",
    "3331122213333122212332..",
    ".33.1122132231221.2332..",
    "33....1221331221..1221..",
    "......1222112221..1221..",
    ".....122332233221.1331..",
    "....122332112332211221..",
    "....122211..112221.33...",
    "...123321....123321.....",
    "...123321....123321.....",
    "...122221....122221.....",
    "..1223321....1233221....",
    "..1223321....1233221....",
    "..1222221....1222221....",
    ".123333221..122333321...",
    ".111111111..111111111...",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
  ];

  const MIDBOSS_GOUF_ROWS = [
    "......33................",
    ".......33.1221.......33.",
    "........3123321.....321.",
    ".......111111111...321..",
    ".......113311111..3221..",
    "..33...122212221132321..",
    ".33...1122222221233221..",
    "33..33122133312223221...",
    ".3331112213231221221....",
    "...31..12213122112221...",
    "..31....1222221.123321..",
    "331.....1223321.123321..",
    ".......122333321122221..",
    "......122211112221111...",
    ".....12221....12221.....",
    "....123321....123321....",
    "....123321....123321....",
    "...1222221....1222221...",
    "...123321......123321...",
    "..1223321......1233221..",
    "..1222221......1222221..",
    ".123333221....122333321.",
    ".111111111....111111111.",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
  ];

  const BOSS_RIVAL_ROWS = [
    ".......33...............",
    "........33..222.........",
    ".........3322322........",
    "........111111111...11..",
    "........113311111..1231.",
    "........122212221.12321.",
    ".3333331122222221123321.",
    "31111111223333222233221.",
    "3113311122322322232221..",
    ".33333..12233221123321..",
    "........12211221123321..",
    ".......122233222123321..",
    "......122332233221221...",
    ".....12233211233221.....",
    "....1222211..1122221....",
    "...1223321....1233221...",
    "...123321......123321...",
    "..1223321......1233221..",
    "..1233321......1233321..",
    "..1222221......1222221..",
    ".122332221....122233221.",
    ".123333221....122333321.",
    "12233333221..12233333221",
    "11111111111..11111111111",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
  ];

  const BOSS_BIGCORE_ROWS = [
    "..............11..11........11..11..............",
    ".............131..131......131..131.............",
    ".........11..12111121......12111121..11.........",
    "........131.1222222221....1222222221.131........",
    "........121123333333321..123333333321121........",
    "....11..12223311111133211233111111332221..11....",
    "...131.1223311111111112222111111111133221.131...",
    "...121123311122222211112211112222221113321121...",
    "..12222311122233332221111112223333222111322221..",
    ".1233331112211111111221111221111111122111333321.",
    "123311111221111133331221122133331111122111113321",
    "132112221221111333333121121333333111122122211231",
    "132112321221113332223321123322233311122123211231",
    "132112321221113323332321123233323311122123211231",
    "132112321221113323332321123233323311122123211231",
    "132112221221113332223321123322233311122122211231",
    "123311111221111333333121121333333111122111113321",
    ".1233331112211113333122112213333111122111333321.",
    "..12222311122111111122111122111111122111322221..",
    "...121123311222222222111111222222222113321121...",
    "...121.1223311111111112222111111111133221.121...",
    "...131..12223333333333211233333333332221..131...",
    "...131..121122222222221..122222222221121..131...",
    "....3...121.1211221121....1211221121.121...3....",
    "........131.121.121121....121121.121.131........",
    "........131.131.121121....121121.131.131........",
    ".........3..131.131131....131131.131..3.........",
    ".............3..131131....131131..3.............",
    ".................3..3......3..3.................",
    ".................2..2......2..2.................",
    "................................................",
    "................................................",
  ];

  const BOSS_VALKYRIE_ROWS = [
    ".12..........................................21.",
    "1232............11..11....11..11............2321",
    "13221..........131..131..131..131..........12231",
    "132121........12221122211222112221........121231",
    "1321121......1233333333223333333321......1211231",
    ".1321121....123211111123321111112321....1211231.",
    ".12321121..12311222222111122222211321..12112321.",
    "..12321121123112333333211233333321132112112321..",
    "..11232112231123211112322321111232113221123211..",
    "...112322232112311333123321333113211232223211...",
    "....1233333222321332231221322331232223333321....",
    "....1232222333321323321221233231233332222321....",
    "...123211112222213233212212332312222211112321...",
    "..12321233211111133223122132233111111233212321..",
    ".1232123333212222133312332133312222123333212321.",
    "123211232232123332111232232111233321232232112321",
    "1321..123321123223333321123333322321123321..1231",
    "121...12221..1232111112112111112321..12221...121",
    "11....1321...1233222221..1222223321...1231....11",
    "......1321....122211221..122112221....1231......",
    ".......33.....1321..13211231..1231.....33.......",
    ".......22.....1321..13211231..1231.....22.......",
    "...............33....33..33....33...............",
    "...............22....22..22....22...............",
    "................................................",
    "................................................",
    "................................................",
    "................................................",
    "................................................",
    "................................................",
    "................................................",
    "................................................",
  ];

  const BOSS_UFO_CARRIER_ROWS = [
    "..............11111111111111111111..............",
    "...........11122222222222222222222111...........",
    ".........112223333333333333333333322211.........",
    ".......1122333111111111111111111113332211.......",
    "......122331112222222222222222222211133221......",
    "....1123311222333333333333333333332221133211....",
    "...122311223332221111111111111122233322113221...",
    "..12331123322211122233333333222111222332113321..",
    ".1232112321111222333222222223332221111232112321.",
    "123211222123321333221333333122333123321222112321",
    "132112332123321332111233332111233123321233211231",
    "132123332112211332133233332331233112211233321231",
    "132123232111111332133233332331233111111232321231",
    "132123332122222332111233332111233222221233321231",
    "123212332133333333221333333122333333331233212321",
    ".1232122112222222333222222223332222222112212321.",
    "..12331111111111122233333333222111111111113321..",
    "...122332222222221111111111111122222222233221...",
    "....1122333333333222222222222223333333332211....",
    "......112222222223333333333333322222222211......",
    ".......1321112222111111111111112222111231.......",
    ".......1321..1321..1321..1231..1231..1231.......",
    ".......1321..1321..1321..1231..1231..1231.......",
    "........33....33....33....33....33....33........",
    "........22....22....22....22....22....22........",
    "................................................",
    "................................................",
    "................................................",
    "................................................",
    "................................................",
    "................................................",
    "................................................",
  ];

  const BOSS_DREADNOUGHT_ROWS = [
    "...11.......11......11....11......11.......11...",
    "..1321.....1321....1321..1231....1231.....1231..",
    "..1321.....1321....1321..1231....1231.....1231..",
    "..1221....123321..123321123321..123321....1221..",
    ".123321..123223211232232232232112322321..123321.",
    ".123321.12321123223211233211232232112321.123321.",
    "123223212321111233211112211112332111123212322321",
    "123223223211222122113331133311221222112322322321",
    "123223332112333211133223322331112333211233322321",
    "123333332123323321332333333233123323321233333321",
    ".1222222112323323132333333332313233232112222221.",
    "..11222111232332313232222223231323323211122211..",
    "..12333211233233213232333323231233233211233321..",
    ".1233223211233321132323333232311233321123223321.",
    "123211123211222111323222222323111222112321112321",
    "1321...1232111111132333333332311111112321...1231",
    "1321....12332222223323333332332222223321....1231",
    "1221.....12333333333223..32233333333321.....1221",
    ".11.......1222222223331..1333222222221.......11.",
    "..........132111321111....111123111231..........",
    "..........1321.1321121....1211231.1231..........",
    "..........1321.1321131....1311231.1231..........",
    "...........33..1321131....1311231..33...........",
    "...........22...33.131....131.33...22...........",
    "................22..3......3..22................",
    "....................2......2....................",
    "................................................",
    "................................................",
    "................................................",
    "................................................",
    "................................................",
    "................................................",
  ];

  const PLAYER_SABER_ROWS_1 = [
    ".............22.",
    "............2332",
    "...........2332.",
    "..........2332..",
    ".........2332...",
    "........2332....",
    ".......2332.....",
    "......2332......",
    ".....2332.......",
    "....2332........",
    "...2332.........",
    "..1131..........",
    ".1331...........",
    ".111............",
    "................",
    "................",
  ];

  const PLAYER_SABER_ROWS_2 = [
    "....22222222....",
    "..223333333322..",
    ".23333333333332.",
    "2333222222223332",
    "2332..1111..2332",
    "232..........232",
    "232..........232",
    ".22....33....22.",
    "......2332......",
    "......2332......",
    "......2332......",
    "......2332......",
    "......1331......",
    "......1331......",
    ".......11.......",
    "................",
  ];

  const PLAYER_SABER_ROWS_3 = [
    ".22.............",
    "2332..11........",
    ".2332...11......",
    "..2332....1.....",
    "...2332.........",
    "....2332........",
    ".....2332.......",
    "......2332......",
    ".......2332.....",
    "........2332....",
    ".........1311...",
    "..........1331..",
    "...........111..",
    "................",
    "................",
    "................",
  ];

  const GUNDAM_SIDE_VIEW_ROWS = [
    "....33...22...33........",
    ".....33.3223.33.........",
    "......33333333..........",
    "......33331331..........",
    "..222..3322333....11....",
    ".23332.33333333111331111",
    "232223233122111333223331",
    "23232321122211111111111.",
    "232323211223311..111....",
    "232323211122111.........",
    "2322232.332233..........",
    ".23332.33311333.........",
    "..222.3332332333........",
    ".....33311..11333.......",
    "....33333....33333......",
    "...33233......33233.....",
    "...33233......33233.....",
    "..333133......333333....",
    "..33113.......331133....",
    ".222222.......331133....",
    "223322........333333....",
    "222222........2222222...",
    "..............2233322...",
    "..............2222222...",
  ];

  const DEFAULT_CHARACTERS = [
    {
      id: "PLAYER_CORE",
      name: "自機 コアファイター (第1形態)",
      category: "player",
      paletteIdx: 0,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(PLAYER_CORE_ROWS_1, 16, 16, 8), parseRowsToFrame(PLAYER_CORE_ROWS_2, 16, 16, 8)],
        fly: [parseRowsToFrame(PLAYER_CORE_ROWS_1, 16, 16, 6), parseRowsToFrame(PLAYER_CORE_ROWS_2, 16, 16, 6)],
        attack: [parseRowsToFrame(PLAYER_CORE_ROWS_2, 16, 16, 6)],
        damage: [parseRowsToFrame(PLAYER_CORE_ROWS_1, 16, 16, 4)],
        destroy: [parseRowsToFrame(PLAYER_CORE_ROWS_2, 16, 16, 4)]
      }
    },
    {
      id: "PLAYER_FORM2",
      name: "自機 第2形態 (コア+脚部 3-WAY)",
      category: "player",
      paletteIdx: 0,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(PLAYER_FORM2_ROWS, 16, 24, 12)],
        fly: [parseRowsToFrame(PLAYER_FORM2_ROWS, 16, 24, 10)],
        attack: [parseRowsToFrame(PLAYER_FORM2_ROWS, 16, 24, 8)],
        damage: [parseRowsToFrame(PLAYER_FORM2_ROWS, 16, 24, 4)],
        destroy: [parseRowsToFrame(PLAYER_FORM2_ROWS, 16, 24, 4)]
      }
    },
    {
      id: "PLAYER_FORM2_5",
      name: "自機 第2.5形態 (コア+胸部 2-WAY)",
      category: "player",
      paletteIdx: 0,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(PLAYER_FORM2_5_ROWS, 16, 24, 12)],
        fly: [parseRowsToFrame(PLAYER_FORM2_5_ROWS, 16, 24, 10)],
        attack: [parseRowsToFrame(PLAYER_FORM2_5_ROWS, 16, 24, 8)],
        damage: [parseRowsToFrame(PLAYER_FORM2_5_ROWS, 16, 24, 4)],
        destroy: [parseRowsToFrame(PLAYER_FORM2_5_ROWS, 16, 24, 4)]
      }
    },
    {
      id: "PLAYER_MS",
      name: "自機 ガンダムMS (第3形態)",
      category: "player",
      paletteIdx: 0,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(PLAYER_MS_ROWS, 24, 24, 12)],
        fly: [parseRowsToFrame(PLAYER_MS_ROWS, 24, 24, 10)],
        attack: [parseRowsToFrame(PLAYER_MS_ROWS, 24, 24, 8)],
        damage: [parseRowsToFrame(PLAYER_MS_ROWS, 24, 24, 4)],
        destroy: [parseRowsToFrame(PLAYER_MS_ROWS, 24, 24, 4)]
      }
    },
    {
      id: "PART_LEG",
      name: "合体パーツ B-PARTS (脚部ユニット)",
      category: "ally",
      paletteIdx: 0,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(PART_LEG_ROWS, 16, 16, 12)],
        fly: [parseRowsToFrame(PART_LEG_ROWS, 16, 16, 10)],
        attack: [parseRowsToFrame(PART_LEG_ROWS, 16, 16, 8)],
        damage: [parseRowsToFrame(PART_LEG_ROWS, 16, 16, 4)],
        destroy: [parseRowsToFrame(PART_LEG_ROWS, 16, 16, 4)]
      }
    },
    {
      id: "PART_CHEST",
      name: "合体パーツ A-PARTS (胸部・頭部ユニット)",
      category: "ally",
      paletteIdx: 0,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(PART_CHEST_ROWS, 16, 16, 12)],
        fly: [parseRowsToFrame(PART_CHEST_ROWS, 16, 16, 10)],
        attack: [parseRowsToFrame(PART_CHEST_ROWS, 16, 16, 8)],
        damage: [parseRowsToFrame(PART_CHEST_ROWS, 16, 16, 4)],
        destroy: [parseRowsToFrame(PART_CHEST_ROWS, 16, 16, 4)]
      }
    },
    {
      id: "ALLY_CARRIER",
      name: "味方支援輸送機 (ガンペリー風キャリア)",
      category: "ally",
      paletteIdx: 3,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(ALLY_CARRIER_ROWS, 16, 16, 12)],
        fly: [parseRowsToFrame(ALLY_CARRIER_ROWS, 16, 16, 10)],
        attack: [parseRowsToFrame(ALLY_CARRIER_ROWS, 16, 16, 8)],
        damage: [parseRowsToFrame(ALLY_CARRIER_ROWS, 16, 16, 4)],
        destroy: [parseRowsToFrame(ALLY_CARRIER_ROWS, 16, 16, 4)]
      }
    },
    {
      id: "ENEMY_SCOUT",
      name: "モジャ・スカウト (Enemy 0: 小型偵察機)",
      category: "enemy",
      paletteIdx: 2,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(ENEMY_SCOUT_ROWS, 16, 16, 12)],
        fly: [parseRowsToFrame(ENEMY_SCOUT_ROWS, 16, 16, 10)],
        attack: [parseRowsToFrame(ENEMY_SCOUT_ROWS, 16, 16, 8)],
        damage: [parseRowsToFrame(ENEMY_SCOUT_ROWS, 16, 16, 4)],
        destroy: [parseRowsToFrame(ENEMY_SCOUT_ROWS, 16, 16, 4)]
      }
    },
    {
      id: "ENEMY_UFO",
      name: "アダムスキー型UFO (Enemy 1: 高速円盤)",
      category: "enemy",
      paletteIdx: 2,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(ENEMY_UFO_ROWS, 16, 16, 12)],
        fly: [parseRowsToFrame(ENEMY_UFO_ROWS, 16, 16, 10)],
        attack: [parseRowsToFrame(ENEMY_UFO_ROWS, 16, 16, 8)],
        damage: [parseRowsToFrame(ENEMY_UFO_ROWS, 16, 16, 4)],
        destroy: [parseRowsToFrame(ENEMY_UFO_ROWS, 16, 16, 4)]
      }
    },
    {
      id: "ENEMY_LANCE",
      name: "ツインランス突撃機 (Enemy 2: 突撃機)",
      category: "enemy",
      paletteIdx: 2,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(ENEMY_LANCE_ROWS, 16, 16, 12)],
        fly: [parseRowsToFrame(ENEMY_LANCE_ROWS, 16, 16, 10)],
        attack: [parseRowsToFrame(ENEMY_LANCE_ROWS, 16, 16, 8)],
        damage: [parseRowsToFrame(ENEMY_LANCE_ROWS, 16, 16, 4)],
        destroy: [parseRowsToFrame(ENEMY_LANCE_ROWS, 16, 16, 4)]
      }
    },
    {
      id: "ENEMY_GUNSHIP",
      name: "重装甲ガンシップ (Enemy 3: 大型重装機)",
      category: "enemy",
      paletteIdx: 2,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(ENEMY_GUNSHIP_ROWS, 16, 16, 12)],
        fly: [parseRowsToFrame(ENEMY_GUNSHIP_ROWS, 16, 16, 10)],
        attack: [parseRowsToFrame(ENEMY_GUNSHIP_ROWS, 16, 16, 8)],
        damage: [parseRowsToFrame(ENEMY_GUNSHIP_ROWS, 16, 16, 4)],
        destroy: [parseRowsToFrame(ENEMY_GUNSHIP_ROWS, 16, 16, 4)]
      }
    },
    {
      id: "MIDBOSS_ZAKU",
      name: "MOJA-01 量産型ザク中ボス (Stage 1)",
      category: "boss",
      paletteIdx: 2,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(MIDBOSS_ZAKU_ROWS, 24, 32, 12)],
        fly: [parseRowsToFrame(MIDBOSS_ZAKU_ROWS, 24, 32, 10)],
        attack: [parseRowsToFrame(MIDBOSS_ZAKU_ROWS, 24, 32, 8)],
        damage: [parseRowsToFrame(MIDBOSS_ZAKU_ROWS, 24, 32, 4)],
        destroy: [parseRowsToFrame(MIDBOSS_ZAKU_ROWS, 24, 32, 4)]
      }
    },
    {
      id: "MIDBOSS_DOM",
      name: "MOJA-02 重装甲ドム中ボス (Stage 2)",
      category: "boss",
      paletteIdx: 1,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(MIDBOSS_DOM_ROWS, 24, 32, 12)],
        fly: [parseRowsToFrame(MIDBOSS_DOM_ROWS, 24, 32, 10)],
        attack: [parseRowsToFrame(MIDBOSS_DOM_ROWS, 24, 32, 8)],
        damage: [parseRowsToFrame(MIDBOSS_DOM_ROWS, 24, 32, 4)],
        destroy: [parseRowsToFrame(MIDBOSS_DOM_ROWS, 24, 32, 4)]
      }
    },
    {
      id: "MIDBOSS_ZGOK",
      name: "MOJA-03 ズゴック水陸中ボス (Stage 3)",
      category: "boss",
      paletteIdx: 2,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(MIDBOSS_ZGOK_ROWS, 24, 32, 12)],
        fly: [parseRowsToFrame(MIDBOSS_ZGOK_ROWS, 24, 32, 10)],
        attack: [parseRowsToFrame(MIDBOSS_ZGOK_ROWS, 24, 32, 8)],
        damage: [parseRowsToFrame(MIDBOSS_ZGOK_ROWS, 24, 32, 4)],
        destroy: [parseRowsToFrame(MIDBOSS_ZGOK_ROWS, 24, 32, 4)]
      }
    },
    {
      id: "MIDBOSS_GOUF",
      name: "MOJA-04 電熱鞭グフ中ボス (Stage 4)",
      category: "boss",
      paletteIdx: 2,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(MIDBOSS_GOUF_ROWS, 24, 32, 12)],
        fly: [parseRowsToFrame(MIDBOSS_GOUF_ROWS, 24, 32, 10)],
        attack: [parseRowsToFrame(MIDBOSS_GOUF_ROWS, 24, 32, 8)],
        damage: [parseRowsToFrame(MIDBOSS_GOUF_ROWS, 24, 32, 4)],
        destroy: [parseRowsToFrame(MIDBOSS_GOUF_ROWS, 24, 32, 4)]
      }
    },
    {
      id: "BOSS_RIVAL",
      name: "宿敵・赤いモビルスーツ (全ステージ決戦)",
      category: "boss",
      paletteIdx: 1,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(BOSS_RIVAL_ROWS, 24, 32, 12)],
        fly: [parseRowsToFrame(BOSS_RIVAL_ROWS, 24, 32, 10)],
        attack: [parseRowsToFrame(BOSS_RIVAL_ROWS, 24, 32, 8)],
        damage: [parseRowsToFrame(BOSS_RIVAL_ROWS, 24, 32, 4)],
        destroy: [parseRowsToFrame(BOSS_RIVAL_ROWS, 24, 32, 4)]
      }
    },
    {
      id: "BOSS_BIGCORE",
      name: "LUNAR BIG-CORE (Stage 1 月面要塞ボス)",
      category: "boss",
      paletteIdx: 3,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(BOSS_BIGCORE_ROWS, 48, 32, 12)],
        fly: [parseRowsToFrame(BOSS_BIGCORE_ROWS, 48, 32, 10)],
        attack: [parseRowsToFrame(BOSS_BIGCORE_ROWS, 48, 32, 8)],
        damage: [parseRowsToFrame(BOSS_BIGCORE_ROWS, 48, 32, 4)],
        destroy: [parseRowsToFrame(BOSS_BIGCORE_ROWS, 48, 32, 4)]
      }
    },
    {
      id: "BOSS_VALKYRIE",
      name: "CRIMSON VALKYRIE (Stage 2 火星要塞ボス)",
      category: "boss",
      paletteIdx: 1,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(BOSS_VALKYRIE_ROWS, 48, 32, 12)],
        fly: [parseRowsToFrame(BOSS_VALKYRIE_ROWS, 48, 32, 10)],
        attack: [parseRowsToFrame(BOSS_VALKYRIE_ROWS, 48, 32, 8)],
        damage: [parseRowsToFrame(BOSS_VALKYRIE_ROWS, 48, 32, 4)],
        destroy: [parseRowsToFrame(BOSS_VALKYRIE_ROWS, 48, 32, 4)]
      }
    },
    {
      id: "BOSS_UFO_CARRIER",
      name: "JUPITER UFO CARRIER (Stage 3 木星超巨大母艦)",
      category: "boss",
      paletteIdx: 2,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(BOSS_UFO_CARRIER_ROWS, 48, 32, 12)],
        fly: [parseRowsToFrame(BOSS_UFO_CARRIER_ROWS, 48, 32, 10)],
        attack: [parseRowsToFrame(BOSS_UFO_CARRIER_ROWS, 48, 32, 8)],
        damage: [parseRowsToFrame(BOSS_UFO_CARRIER_ROWS, 48, 32, 4)],
        destroy: [parseRowsToFrame(BOSS_UFO_CARRIER_ROWS, 48, 32, 4)]
      }
    },
    {
      id: "BOSS_DREADNOUGHT",
      name: "EMPEROR DREADNOUGHT (Stage 4 最終皇帝要塞艦)",
      category: "boss",
      paletteIdx: 3,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(BOSS_DREADNOUGHT_ROWS, 48, 32, 12)],
        fly: [parseRowsToFrame(BOSS_DREADNOUGHT_ROWS, 48, 32, 10)],
        attack: [parseRowsToFrame(BOSS_DREADNOUGHT_ROWS, 48, 32, 8)],
        damage: [parseRowsToFrame(BOSS_DREADNOUGHT_ROWS, 48, 32, 4)],
        destroy: [parseRowsToFrame(BOSS_DREADNOUGHT_ROWS, 48, 32, 4)]
      }
    },
    {
      id: "PLAYER_SABER",
      name: "ビームサーベル大一閃 (抜刀・一閃・残心)",
      category: "player",
      paletteIdx: 0,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(PLAYER_SABER_ROWS_1, 16, 16, 8), parseRowsToFrame(PLAYER_SABER_ROWS_2, 16, 16, 8), parseRowsToFrame(PLAYER_SABER_ROWS_3, 16, 16, 8)],
        fly: [parseRowsToFrame(PLAYER_SABER_ROWS_1, 16, 16, 6), parseRowsToFrame(PLAYER_SABER_ROWS_2, 16, 16, 6), parseRowsToFrame(PLAYER_SABER_ROWS_3, 16, 16, 6)],
        attack: [parseRowsToFrame(PLAYER_SABER_ROWS_2, 16, 16, 8)],
        damage: [parseRowsToFrame(PLAYER_SABER_ROWS_1, 16, 16, 4)],
        destroy: [parseRowsToFrame(PLAYER_SABER_ROWS_3, 16, 16, 4)]
      }
    },
    {
      id: "GUNDAM_SIDE_VIEW",
      name: "ガンダムMS (横画面 1-on-1 ライフル構え)",
      category: "player",
      paletteIdx: 0,
      subpalettes: createDefaultSubpalettes(),
      animations: {
        idle: [parseRowsToFrame(GUNDAM_SIDE_VIEW_ROWS, 24, 24, 12)],
        fly: [parseRowsToFrame(GUNDAM_SIDE_VIEW_ROWS, 24, 24, 10)],
        attack: [parseRowsToFrame(GUNDAM_SIDE_VIEW_ROWS, 24, 24, 8)],
        damage: [parseRowsToFrame(GUNDAM_SIDE_VIEW_ROWS, 24, 24, 4)],
        destroy: [parseRowsToFrame(GUNDAM_SIDE_VIEW_ROWS, 24, 24, 4)]
      }
    },
  ];

// =============================================================================
// Editor State
// =============================================================================

class CharacterEditorApp {
  constructor() {
    this.characters = JSON.parse(JSON.stringify(DEFAULT_CHARACTERS));
    this.currentCharIndex = 0;
    this.currentAnimState = "idle";
    this.currentFrameIndex = 0;
    this.zoom = 12;
    
    // Viewport options
    this.showTileGrid = true;
    this.showPixelGrid = false;
    this.showOnionSkin = true;
    this.showHurtbox = true;
    this.showHitbox = true;
    this.showScanlineWarning = true;

    // Animation playback state
    this.isPlaying = false;
    this.animLoop = true;
    this.playTickCounter = 0;
    this.animFrameReq = null;

    // Canvas interaction (drag/resize boxes)
    this.dragTarget = null; // 'hurtbox' | 'hitbox' | 'hurt-corner' | 'hit-corner'
    this.dragStart = { x: 0, y: 0 };
    this.boxStart = { x: 0, y: 0, w: 0, h: 0 };

    // Palette modal state
    this.editingPalSlot = 1;

    this.initDOM();
    this.bindEvents();
    this.updateAllUI();
    this.startRenderLoop();
  }

  get currentChar() {
    return this.characters[this.currentCharIndex] || this.characters[0];
  }

  get currentAnimation() {
    const char = this.currentChar;
    if (!char.animations[this.currentAnimState]) {
      char.animations[this.currentAnimState] = [generateCoreFighterFrame()];
    }
    return char.animations[this.currentAnimState];
  }

  get currentFrame() {
    const anim = this.currentAnimation;
    if (this.currentFrameIndex >= anim.length) {
      this.currentFrameIndex = Math.max(0, anim.length - 1);
    }
    return anim[this.currentFrameIndex] || anim[0];
  }

  initDOM() {
    this.canvas = document.getElementById('mainCanvas');
    this.ctx = this.canvas.getContext('2d');
    this.scanlineRuler = document.getElementById('scanlineRuler');
    this.chrMeterFill = document.getElementById('chrMeterFill');
    this.chrMeterText = document.getElementById('chrMeterText');
    this.charListEl = document.getElementById('charList');
    this.frameStripEl = document.getElementById('frameStrip');
    this.tileBankGridEl = document.getElementById('tileBankGrid');
    this.tileBankCountEl = document.getElementById('tileBankCount');

    // Inputs
    this.inpFrameDuration = document.getElementById('inp-frame-duration');
    this.inpHurtX = document.getElementById('inp-hurt-x');
    this.inpHurtY = document.getElementById('inp-hurt-y');
    this.inpHurtW = document.getElementById('inp-hurt-w');
    this.inpHurtH = document.getElementById('inp-hurt-h');
    this.lblHurtHalf = document.getElementById('lbl-hurt-half');

    this.inpHitX = document.getElementById('inp-hit-x');
    this.inpHitY = document.getElementById('inp-hit-y');
    this.inpHitW = document.getElementById('inp-hit-w');
    this.inpHitH = document.getElementById('inp-hit-h');
    this.lblHitHalf = document.getElementById('lbl-hit-half');

    // Master Palette Grid
    this.initNesMasterPaletteModal();
  }

  initNesMasterPaletteModal() {
    const grid = document.getElementById('nesMasterPaletteGrid');
    grid.innerHTML = '';
    NES_MASTER_PALETTE.forEach(c => {
      const cell = document.createElement('div');
      cell.className = 'nes-color-cell';
      cell.style.backgroundColor = c.hex;
      cell.title = `$${c.id.toString(16).padStart(2, '0').toUpperCase()} (${c.name})`;
      cell.addEventListener('click', () => {
        this.selectNesMasterColor(c.id);
      });
      grid.appendChild(cell);
    });
  }

  bindEvents() {
    // Zoom
    document.getElementById('sel-zoom').addEventListener('change', (e) => {
      this.zoom = parseInt(e.target.value, 10);
      this.resizeCanvas();
    });

    // Checkboxes
    document.getElementById('chk-grid').addEventListener('change', (e) => {
      this.showTileGrid = e.target.checked;
    });
    document.getElementById('chk-pixel-grid').addEventListener('change', (e) => {
      this.showPixelGrid = e.target.checked;
    });
    document.getElementById('chk-onion').addEventListener('change', (e) => {
      this.showOnionSkin = e.target.checked;
    });
    document.getElementById('chk-hurtbox').addEventListener('change', (e) => {
      this.showHurtbox = e.target.checked;
    });
    document.getElementById('chk-hitbox').addEventListener('change', (e) => {
      this.showHitbox = e.target.checked;
    });
    document.getElementById('chk-scanline-warning').addEventListener('change', (e) => {
      this.showScanlineWarning = e.target.checked;
    });
    document.getElementById('chk-anim-loop').addEventListener('change', (e) => {
      this.animLoop = e.target.checked;
    });

    // Animation Play / Pause
    const btnPlay = document.getElementById('btn-play-anim');
    btnPlay.addEventListener('click', () => {
      this.isPlaying = !this.isPlaying;
      btnPlay.textContent = this.isPlaying ? "⏸ 停止" : "▶ 再生";
      btnPlay.className = this.isPlaying ? "btn btn-sm btn-purple" : "btn btn-sm btn-primary";
    });

    document.getElementById('btn-prev-frame').addEventListener('click', () => {
      if (this.currentFrameIndex > 0) {
        this.currentFrameIndex--;
        this.updateFrameControls();
      }
    });

    document.getElementById('btn-next-frame').addEventListener('click', () => {
      const anim = this.currentAnimation;
      if (this.currentFrameIndex < anim.length - 1) {
        this.currentFrameIndex++;
        this.updateFrameControls();
      }
    });

    document.getElementById('btn-add-frame').addEventListener('click', () => {
      const anim = this.currentAnimation;
      const copy = JSON.parse(JSON.stringify(this.currentFrame));
      copy.duration = 10;
      anim.splice(this.currentFrameIndex + 1, 0, copy);
      this.currentFrameIndex++;
      this.updateAllUI();
    });

    document.getElementById('btn-del-frame').addEventListener('click', () => {
      const anim = this.currentAnimation;
      if (anim.length <= 1) {
        alert("アニメーションには最低1コマ必要です。");
        return;
      }
      anim.splice(this.currentFrameIndex, 1);
      this.currentFrameIndex = Math.max(0, this.currentFrameIndex - 1);
      this.updateAllUI();
    });

    this.inpFrameDuration.addEventListener('input', (e) => {
      const val = Math.max(1, parseInt(e.target.value, 10) || 1);
      this.currentFrame.duration = val;
      this.renderFrameStrip();
    });

    // Subpalette selector
    document.getElementById('sel-subpalette-idx').addEventListener('change', (e) => {
      this.currentChar.paletteIdx = parseInt(e.target.value, 10);
      this.updatePaletteSlots();
    });

    // Palette Slots Click
    [1, 2, 3].forEach(slot => {
      document.getElementById(`pal-slot-${slot}`).addEventListener('click', () => {
        this.editingPalSlot = slot;
        document.getElementById('modal-palette-picker').style.display = 'flex';
      });
    });

    document.getElementById('btn-close-palette-modal').addEventListener('click', () => {
      document.getElementById('modal-palette-picker').style.display = 'none';
    });

    // State Chips
    document.getElementById('animStateSelector').addEventListener('click', (e) => {
      if (e.target.classList.contains('state-chip')) {
        document.querySelectorAll('.state-chip').forEach(c => c.classList.remove('active'));
        e.target.classList.add('active');
        this.currentAnimState = e.target.getAttribute('data-state');
        this.currentFrameIndex = 0;
        this.updateAllUI();
      }
    });

    // Character Management Buttons
    document.getElementById('btn-add-char').addEventListener('click', () => {
      const name = prompt("新規キャラクター名を入力してください:", "新キャラ");
      if (!name) return;
      const newChar = {
        id: "CHAR_" + Date.now().toString(36).toUpperCase(),
        name,
        category: "enemy",
        paletteIdx: 0,
        subpalettes: createDefaultSubpalettes(),
        animations: {
          idle: [generateCoreFighterFrame()]
        }
      };
      this.characters.push(newChar);
      this.currentCharIndex = this.characters.length - 1;
      this.currentAnimState = "idle";
      this.currentFrameIndex = 0;
      this.updateAllUI();
    });

    document.getElementById('btn-dup-char').addEventListener('click', () => {
      const copy = JSON.parse(JSON.stringify(this.currentChar));
      copy.id = copy.id + "_COPY";
      copy.name = copy.name + " (複製)";
      this.characters.push(copy);
      this.currentCharIndex = this.characters.length - 1;
      this.updateAllUI();
    });

    document.getElementById('btn-del-char').addEventListener('click', () => {
      if (this.characters.length <= 1) {
        alert("最低1つのキャラクターが必要です。");
        return;
      }
      if (!confirm(`キャラクター「${this.currentChar.name}」を削除しますか？`)) return;
      this.characters.splice(this.currentCharIndex, 1);
      this.currentCharIndex = Math.max(0, this.currentCharIndex - 1);
      this.updateAllUI();
    });

    document.getElementById('btn-duplicate-variation').addEventListener('click', () => {
      const copy = JSON.parse(JSON.stringify(this.currentChar));
      const nextPal = (copy.paletteIdx + 1) % 4;
      copy.paletteIdx = nextPal;
      copy.id = copy.id + "_PAL" + nextPal;
      copy.name = copy.name + ` [パレット${nextPal}]`;
      this.characters.push(copy);
      this.currentCharIndex = this.characters.length - 1;
      this.updateAllUI();
    });

    // Hitbox/Hurtbox inputs
    const syncBoxesFromInputs = () => {
      const frame = this.currentFrame;
      frame.hurtbox = {
        x: parseInt(this.inpHurtX.value, 10) || 0,
        y: parseInt(this.inpHurtY.value, 10) || 0,
        w: Math.max(1, parseInt(this.inpHurtW.value, 10) || 1),
        h: Math.max(1, parseInt(this.inpHurtH.value, 10) || 1),
      };
      frame.hitbox = {
        x: parseInt(this.inpHitX.value, 10) || 0,
        y: parseInt(this.inpHitY.value, 10) || 0,
        w: Math.max(1, parseInt(this.inpHitW.value, 10) || 1),
        h: Math.max(1, parseInt(this.inpHitH.value, 10) || 1),
      };
      this.lblHurtHalf.textContent = `${Math.round(frame.hurtbox.w / 2)} x ${Math.round(frame.hurtbox.h / 2)} px`;
      this.lblHitHalf.textContent = `${Math.round(frame.hitbox.w / 2)} x ${Math.round(frame.hitbox.h / 2)} px`;
    };

    [this.inpHurtX, this.inpHurtY, this.inpHurtW, this.inpHurtH,
     this.inpHitX, this.inpHitY, this.inpHitW, this.inpHitH].forEach(inp => {
      inp.addEventListener('input', syncBoxesFromInputs);
    });

    // Image Dropzone
    this.setupDropzone();

    // Canvas Mouse Interaction for Hitbox / Hurtbox
    this.setupCanvasInteractions();

    // JSON Import/Export
    this.setupJsonModals();

    // ca65 ASM Export
    this.setupAsmExport();
  }

  setupDropzone() {
    const dropzone = document.getElementById('dropzone');
    const inpFile = document.getElementById('inp-image-file');

    dropzone.addEventListener('click', () => inpFile.click());
    dropzone.addEventListener('dragover', (e) => {
      e.preventDefault();
      dropzone.classList.add('dragover');
    });
    dropzone.addEventListener('dragleave', () => dropzone.classList.remove('dragover'));
    dropzone.addEventListener('drop', (e) => {
      e.preventDefault();
      dropzone.classList.remove('dragover');
      if (e.dataTransfer.files.length > 0) {
        this.processImportImage(e.dataTransfer.files[0]);
      }
    });

    inpFile.addEventListener('change', (e) => {
      if (e.target.files.length > 0) {
        this.processImportImage(e.target.files[0]);
      }
    });
  }

  processImportImage(file) {
    const reader = new FileReader();
    reader.onload = (ev) => {
      const img = new Image();
      img.onload = () => {
        // Create hidden canvas to get ImageData
        const tempCanvas = document.createElement('canvas');
        tempCanvas.width = img.width;
        tempCanvas.height = img.height;
        const tempCtx = tempCanvas.getContext('2d');
        tempCtx.drawImage(img, 0, 0);

        // Auto downscale pixel-art grid & auto detect black/solid background
        const downscaled = autoDownscalePixelArt(tempCanvas, img);
        const { width, height, imgData, solidBg, wasDownscaled, factor } = downscaled;

        // Quantize to NES subpalette (ignoring solid background)
        const { subpalette, indexedPixels } = quantizeImageToNesSubpalette(imgData, 64, solidBg);

        // Decompose into 8x8 tiles with duplicate culling
        const { spriteInstances, deduplicatedTiles } = decomposeIntoMetaSprites(width, height, indexedPixels);

        // Update current character's subpalette
        const palIdx = this.currentChar.paletteIdx;
        const palSlots = [0x0f];
        for (let i = 1; i <= 3; i++) {
          palSlots.push(subpalette[i] ? subpalette[i].id : 0x00);
        }
        this.currentChar.subpalettes[palIdx] = palSlots;

        // Create new frame
        const newFrame = {
          duration: 12,
          width,
          height,
          tiles: deduplicatedTiles,
          sprites: spriteInstances,
          hurtbox: { x: 2, y: 2, w: width - 4, h: height - 4 },
          hitbox: { x: 4, y: 4, w: Math.max(2, width - 8), h: Math.max(2, height - 8) }
        };

        const anim = this.currentAnimation;
        anim[this.currentFrameIndex] = newFrame;

        let msg = `🎉 画像を正常に読み込みました！\nサイズ: ${width}x${height} px\nスプライト数: ${spriteInstances.length} 枚\n生成8x8タイル: ${deduplicatedTiles.length} 個 (重複除外済)`;
        if (wasDownscaled) {
          msg += `\n\n💡 元画像 (${img.width}x${img.height} px) から 1ドット=${factor}px を自動検知し、${width}x${height} px の実機ドット絵へ自動縮小しました。`;
        }
        if (solidBg) {
          msg += `\n💡 JPEG等の背景色（黒色など）を自動検知して透過しました。`;
        }
        alert(msg);
        this.updateAllUI();
      };
      img.src = ev.target.result;
    };
    reader.readAsDataURL(file);
  }

  setupCanvasInteractions() {
    this.canvas.addEventListener('mousedown', (e) => {
      const rect = this.canvas.getBoundingClientRect();
      const mx = (e.clientX - rect.left) / this.zoom;
      const my = (e.clientY - rect.top) / this.zoom;

      const frame = this.currentFrame;
      const hit = frame.hitbox;
      const hurt = frame.hurtbox;

      // Check corner handles first (radius 4px)
      if (this.showHitbox && Math.abs(mx - (hit.x + hit.w)) < 4 && Math.abs(my - (hit.y + hit.h)) < 4) {
        this.dragTarget = 'hit-corner';
      } else if (this.showHurtbox && Math.abs(mx - (hurt.x + hurt.w)) < 4 && Math.abs(my - (hurt.y + hurt.h)) < 4) {
        this.dragTarget = 'hurt-corner';
      } else if (this.showHitbox && mx >= hit.x && mx <= hit.x + hit.w && my >= hit.y && my <= hit.y + hit.h) {
        this.dragTarget = 'hitbox';
      } else if (this.showHurtbox && mx >= hurt.x && mx <= hurt.x + hurt.w && my >= hurt.y && my <= hurt.y + hurt.h) {
        this.dragTarget = 'hurtbox';
      } else {
        this.dragTarget = null;
      }

      if (this.dragTarget) {
        this.dragStart = { x: mx, y: my };
        const box = this.dragTarget.startsWith('hit') ? hit : hurt;
        this.boxStart = { x: box.x, y: box.y, w: box.w, h: box.h };
      }
    });

    window.addEventListener('mousemove', (e) => {
      if (!this.dragTarget) return;
      const rect = this.canvas.getBoundingClientRect();
      const mx = (e.clientX - rect.left) / this.zoom;
      const my = (e.clientY - rect.top) / this.zoom;
      const dx = Math.round(mx - this.dragStart.x);
      const dy = Math.round(my - this.dragStart.y);

      const frame = this.currentFrame;
      if (this.dragTarget === 'hitbox') {
        frame.hitbox.x = this.boxStart.x + dx;
        frame.hitbox.y = this.boxStart.y + dy;
      } else if (this.dragTarget === 'hurtbox') {
        frame.hurtbox.x = this.boxStart.x + dx;
        frame.hurtbox.y = this.boxStart.y + dy;
      } else if (this.dragTarget === 'hit-corner') {
        frame.hitbox.w = Math.max(2, this.boxStart.w + dx);
        frame.hitbox.h = Math.max(2, this.boxStart.h + dy);
      } else if (this.dragTarget === 'hurt-corner') {
        frame.hurtbox.w = Math.max(2, this.boxStart.w + dx);
        frame.hurtbox.h = Math.max(2, this.boxStart.h + dy);
      }
      this.updateHitboxInputs();
    });

    window.addEventListener('mouseup', () => {
      this.dragTarget = null;
    });
  }

  selectNesMasterColor(colorId) {
    const palIdx = this.currentChar.paletteIdx;
    this.currentChar.subpalettes[palIdx][this.editingPalSlot] = colorId;
    document.getElementById('modal-palette-picker').style.display = 'none';
    this.updatePaletteSlots();
  }

  updateAllUI() {
    this.renderCharList();
    this.updatePaletteSlots();
    this.updateFrameControls();
    this.renderFrameStrip();
    this.updateTileBank();
    this.updateChrBudgetMeter();
    this.updateHitboxInputs();
    this.resizeCanvas();
  }

  resizeCanvas() {
    const frame = this.currentFrame;
    const fw = frame.width || 16;
    const fh = frame.height || 16;
    this.canvas.width = fw * this.zoom;
    this.canvas.height = fh * this.zoom;
    this.scanlineRuler.style.height = `${this.canvas.height}px`;
  }

  renderCharList() {
    this.charListEl.innerHTML = '';
    this.characters.forEach((char, idx) => {
      const item = document.createElement('div');
      item.className = 'char-item' + (idx === this.currentCharIndex ? ' active' : '');
      item.innerHTML = `
        <div>
          <div class="char-item-name">${char.name}</div>
          <div class="char-item-meta">${char.id} (${char.category})</div>
        </div>
      `;
      item.addEventListener('click', () => {
        this.currentCharIndex = idx;
        this.currentFrameIndex = 0;
        this.updateAllUI();
      });
      this.charListEl.appendChild(item);
    });
  }

  updatePaletteSlots() {
    const palIdx = this.currentChar.paletteIdx;
    document.getElementById('sel-subpalette-idx').value = palIdx;
    const subpal = this.currentChar.subpalettes[palIdx] || [0x0f, 0x00, 0x16, 0x20];

    for (let slot = 1; slot <= 3; slot++) {
      const colorId = subpal[slot];
      const nesCol = NES_MASTER_PALETTE.find(c => c.id === colorId) || NES_MASTER_PALETTE[0];
      const el = document.getElementById(`pal-slot-${slot}`);
      el.style.backgroundColor = nesCol.hex;
      el.innerHTML = `
        <span>$${colorId.toString(16).padStart(2, '0').toUpperCase()}</span>
        <small style="font-size:9px; color:#fff;">${nesCol.name}</small>
      `;
    }
  }

  updateFrameControls() {
    const anim = this.currentAnimation;
    const frame = this.currentFrame;
    this.inpFrameDuration.value = frame.duration || 12;

    // Prev/Next enable
    document.getElementById('btn-prev-frame').disabled = (this.currentFrameIndex <= 0);
    document.getElementById('btn-next-frame').disabled = (this.currentFrameIndex >= anim.length - 1);
  }

  renderFrameStrip() {
    this.frameStripEl.innerHTML = '';
    const anim = this.currentAnimation;
    anim.forEach((fr, idx) => {
      const card = document.createElement('div');
      card.className = 'frame-card' + (idx === this.currentFrameIndex ? ' active' : '');
      card.innerHTML = `
        <div class="frame-card-meta">#${idx + 1} (${fr.duration}f)</div>
        <div class="frame-card-thumb" id="thumb-${idx}"></div>
      `;
      card.addEventListener('click', () => {
        this.currentFrameIndex = idx;
        this.updateFrameControls();
        this.renderFrameStrip();
        this.updateHitboxInputs();
        this.resizeCanvas();
      });
      this.frameStripEl.appendChild(card);
    });
  }

  updateTileBank() {
    const frame = this.currentFrame;
    const tiles = frame.tiles || [];
    this.tileBankCountEl.textContent = `${tiles.length} tiles`;
    this.tileBankGridEl.innerHTML = '';

    const palIdx = this.currentChar.paletteIdx;
    const subpal = this.currentChar.subpalettes[palIdx];
    const colors = subpal.map(id => {
      const c = NES_MASTER_PALETTE.find(x => x.id === id);
      return c ? c.hex : '#000000';
    });

    tiles.forEach((tile64, idx) => {
      const thumb = document.createElement('canvas');
      thumb.className = 'tile-bank-thumb';
      thumb.width = 8;
      thumb.height = 8;
      thumb.title = `Tile ${idx}`;
      const tctx = thumb.getContext('2d');
      const imgData = tctx.createImageData(8, 8);
      for (let i = 0; i < 64; i++) {
        const val = tile64[i];
        const hex = val === 0 ? '#000000' : colors[val];
        const r = parseInt(hex.slice(1, 3), 16);
        const g = parseInt(hex.slice(3, 5), 16);
        const b = parseInt(hex.slice(5, 7), 16);
        const a = val === 0 ? 0 : 255;
        imgData.data[i * 4 + 0] = r;
        imgData.data[i * 4 + 1] = g;
        imgData.data[i * 4 + 2] = b;
        imgData.data[i * 4 + 3] = a;
      }
      tctx.putImageData(imgData, 0, 0);
      this.tileBankGridEl.appendChild(thumb);
    });
  }

  updateChrBudgetMeter() {
    // Count all deduplicated tiles across all characters and all animation frames
    const allSignatures = new Set();
    this.characters.forEach(char => {
      Object.values(char.animations).forEach(frames => {
        frames.forEach(fr => {
          if (fr.tiles) {
            fr.tiles.forEach(t => allSignatures.add(Array.from(t).join(',')));
          }
        });
      });
    });

    const totalTiles = allSignatures.size;
    const percent = Math.min(100, Math.round((totalTiles / 256) * 100));

    this.chrMeterFill.style.width = `${percent}%`;
    this.chrMeterText.textContent = `${totalTiles} / 256 tiles (${percent}%)`;

    this.chrMeterFill.className = 'chr-meter-fill';
    if (totalTiles > 256) {
      this.chrMeterFill.classList.add('danger');
      this.chrMeterText.style.color = '#f85149';
    } else if (totalTiles > 192) {
      this.chrMeterFill.classList.add('warning');
      this.chrMeterText.style.color = '#d29922';
    } else {
      this.chrMeterText.style.color = 'var(--text-main)';
    }
  }

  updateHitboxInputs() {
    const frame = this.currentFrame;
    const hurt = frame.hurtbox || { x: 0, y: 0, w: 16, h: 16 };
    const hit = frame.hitbox || { x: 2, y: 2, w: 12, h: 12 };

    this.inpHurtX.value = hurt.x;
    this.inpHurtY.value = hurt.y;
    this.inpHurtW.value = hurt.w;
    this.inpHurtH.value = hurt.h;
    this.lblHurtHalf.textContent = `${Math.round(hurt.w / 2)} x ${Math.round(hurt.h / 2)} px`;

    this.inpHitX.value = hit.x;
    this.inpHitY.value = hit.y;
    this.inpHitW.value = hit.w;
    this.inpHitH.value = hit.h;
    this.lblHitHalf.textContent = `${Math.round(hit.w / 2)} x ${Math.round(hit.h / 2)} px`;
  }

  startRenderLoop() {
    const loop = () => {
      this.render();
      if (this.isPlaying) {
        this.playTickCounter++;
        const frame = this.currentFrame;
        const dur = frame.duration || 10;
        if (this.playTickCounter >= dur) {
          this.playTickCounter = 0;
          const anim = this.currentAnimation;
          if (this.currentFrameIndex < anim.length - 1) {
            this.currentFrameIndex++;
          } else if (this.animLoop) {
            this.currentFrameIndex = 0;
          }
          this.updateFrameControls();
          this.renderFrameStrip();
          this.updateHitboxInputs();
        }
      }
      this.animFrameReq = requestAnimationFrame(loop);
    };
    loop();
  }

  render() {
    const ctx = this.ctx;
    const z = this.zoom;
    const w = this.canvas.width;
    const h = this.canvas.height;
    ctx.clearRect(0, 0, w, h);

    const frame = this.currentFrame;
    const palIdx = this.currentChar.paletteIdx;
    const subpal = this.currentChar.subpalettes[palIdx];
    const colors = subpal.map(id => {
      const c = NES_MASTER_PALETTE.find(x => x.id === id);
      return c ? c.hex : '#000000';
    });

    // 1. Render Onion Skin (Previous frame with 30% alpha)
    if (this.showOnionSkin && !this.isPlaying && this.currentFrameIndex > 0) {
      const prevFrame = this.currentAnimation[this.currentFrameIndex - 1];
      if (prevFrame) {
        ctx.save();
        ctx.globalAlpha = 0.3;
        this.drawFrameSprites(ctx, prevFrame, colors, z);
        ctx.restore();
      }
    }

    // 2. Render Current Frame Sprites
    this.drawFrameSprites(ctx, frame, colors, z);

    // 3. Render 8x8 Tile Grid
    if (this.showTileGrid) {
      ctx.strokeStyle = "rgba(88, 166, 255, 0.4)";
      ctx.lineWidth = 1;
      for (let x = 0; x <= w; x += 8 * z) {
        ctx.beginPath();
        ctx.moveTo(x + 0.5, 0);
        ctx.lineTo(x + 0.5, h);
        ctx.stroke();
      }
      for (let y = 0; y <= h; y += 8 * z) {
        ctx.beginPath();
        ctx.moveTo(0, y + 0.5);
        ctx.lineTo(w, y + 0.5);
        ctx.stroke();
      }
    }

    // 4. Render 1px Pixel Grid
    if (this.showPixelGrid && z >= 4) {
      ctx.strokeStyle = "rgba(255, 255, 255, 0.08)";
      ctx.lineWidth = 1;
      for (let x = 0; x <= w; x += z) {
        ctx.beginPath();
        ctx.moveTo(x + 0.5, 0);
        ctx.lineTo(x + 0.5, h);
        ctx.stroke();
      }
      for (let y = 0; y <= h; y += z) {
        ctx.beginPath();
        ctx.moveTo(0, y + 0.5);
        ctx.lineTo(w, y + 0.5);
        ctx.stroke();
      }
    }

    // 5. Render Hurtbox (Blue)
    if (this.showHurtbox && frame.hurtbox) {
      const b = frame.hurtbox;
      ctx.fillStyle = "rgba(88, 166, 255, 0.2)";
      ctx.fillRect(b.x * z, b.y * z, b.w * z, b.h * z);
      ctx.strokeStyle = "#58a6ff";
      ctx.lineWidth = 2;
      ctx.strokeRect(b.x * z, b.y * z, b.w * z, b.h * z);

      // Handle corner
      ctx.fillStyle = "#58a6ff";
      ctx.fillRect((b.x + b.w) * z - 4, (b.y + b.h) * z - 4, 8, 8);
    }

    // 6. Render Hitbox (Red)
    if (this.showHitbox && frame.hitbox) {
      const b = frame.hitbox;
      ctx.fillStyle = "rgba(248, 81, 73, 0.25)";
      ctx.fillRect(b.x * z, b.y * z, b.w * z, b.h * z);
      ctx.strokeStyle = "#f85149";
      ctx.lineWidth = 2;
      ctx.strokeRect(b.x * z, b.y * z, b.w * z, b.h * z);

      // Handle corner
      ctx.fillStyle = "#f85149";
      ctx.fillRect((b.x + b.w) * z - 4, (b.y + b.h) * z - 4, 8, 8);
    }

    // 7. Scanline 8-Sprite Hardware Warning (Left ruler & red line overlays)
    this.renderScanlineWarnings(frame, z, w, h);
  }

  drawFrameSprites(ctx, frame, colors, z) {
    const sprites = frame.sprites || [];
    const tiles = frame.tiles || [];

    sprites.forEach(sp => {
      const tile = tiles[sp.tileIndex];
      if (!tile) return;
      const startX = sp.relX * z;
      const startY = sp.relY * z;

      for (let py = 0; py < 8; py++) {
        for (let px = 0; px < 8; px++) {
          const val = tile[py * 8 + px];
          if (val === 0) continue; // transparent
          ctx.fillStyle = colors[val];
          ctx.fillRect(startX + px * z, startY + py * z, z, z);
        }
      }
    });
  }

  renderScanlineWarnings(frame, z, w, h) {
    this.scanlineRuler.innerHTML = '';
    if (!this.showScanlineWarning) return;

    const sprites = frame.sprites || [];
    const heightInPx = Math.ceil(h / z);
    const { maxCount, overloadedLines } = analyzeScanlineDensity(sprites, heightInPx);

    overloadedLines.forEach(line => {
      const indicator = document.createElement('div');
      indicator.className = 'scanline-warning-indicator';
      indicator.style.top = `${line.y * z}px`;
      indicator.style.height = `${z}px`;
      indicator.title = `スキャンライン Y=${line.y}: ${line.count} 枚 (8枚制限超過!)`;
      this.scanlineRuler.appendChild(indicator);

      // Draw faint red line across canvas
      this.ctx.fillStyle = "rgba(248, 81, 73, 0.25)";
      this.ctx.fillRect(0, line.y * z, w, z);
    });
  }

  setupJsonModals() {
    const modal = document.getElementById('modal-json');
    const textArea = document.getElementById('jsonExportText');
    const inpFile = document.getElementById('inp-import-json');

    document.getElementById('btn-export-json').addEventListener('click', () => {
      document.getElementById('modalJsonTitle').textContent = "💾 characters.json エクスポート";
      const data = {
        magic: "NESCHAR01",
        version: "1.0.0",
        characters: this.characters
      };
      textArea.value = JSON.stringify(data, null, 2);
      modal.style.display = 'flex';
    });

    document.getElementById('btn-import-json').addEventListener('click', () => inpFile.click());
    inpFile.addEventListener('change', (e) => {
      if (e.target.files.length > 0) {
        const reader = new FileReader();
        reader.onload = (ev) => {
          try {
            const data = JSON.parse(ev.target.result);
            if (data.characters && Array.isArray(data.characters)) {
              this.characters = data.characters;
              this.currentCharIndex = 0;
              this.currentFrameIndex = 0;
              this.updateAllUI();
              alert("characters.json を正常に読み込みました！");
            } else {
              alert("無効な characters.json 形式です。");
            }
          } catch (err) {
            alert("JSON パースエラー: " + err.message);
          }
        };
        reader.readAsText(e.target.files[0]);
      }
    });

    document.getElementById('btn-copy-json').addEventListener('click', () => {
      navigator.clipboard.writeText(textArea.value).then(() => alert("クリップボードにコピーしました！"));
    });

    document.getElementById('btn-download-json').addEventListener('click', () => {
      const blob = new Blob([textArea.value], { type: 'application/json' });
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = 'characters.json';
      a.click();
    });

    document.getElementById('btn-close-json-modal').addEventListener('click', () => modal.style.display = 'none');
    document.getElementById('btn-dismiss-json').addEventListener('click', () => modal.style.display = 'none');
  }

  setupAsmExport() {
    const modal = document.getElementById('modal-export-asm');
    const textArea = document.getElementById('asmExportText');
    const tabOam = document.getElementById('tab-asm-oam');
    const tabChr = document.getElementById('tab-asm-chr');
    let activeTab = 'oam';

    const refreshAsmText = () => {
      if (activeTab === 'oam') {
        tabOam.className = 'btn btn-sm active btn-purple';
        tabChr.className = 'btn btn-sm';
        textArea.value = this.generateOamDataAssembly();
      } else {
        tabChr.className = 'btn btn-sm active btn-purple';
        tabOam.className = 'btn btn-sm';
        textArea.value = this.generateChrDataAssembly();
      }
    };

    document.getElementById('btn-export-asm').addEventListener('click', () => {
      activeTab = 'oam';
      refreshAsmText();
      modal.style.display = 'flex';
    });

    tabOam.addEventListener('click', () => {
      activeTab = 'oam';
      refreshAsmText();
    });

    tabChr.addEventListener('click', () => {
      activeTab = 'chr';
      refreshAsmText();
    });

    document.getElementById('btn-copy-asm').addEventListener('click', () => {
      navigator.clipboard.writeText(textArea.value).then(() => alert("アセンブリコードをクリップボードにコピーしました！"));
    });

    document.getElementById('btn-download-asm').addEventListener('click', () => {
      const filename = activeTab === 'oam' ? 'character_data.s' : 'character_tiles.s';
      const blob = new Blob([textArea.value], { type: 'text/plain;charset=utf-8' });
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = filename;
      a.click();
    });

    document.getElementById('btn-close-asm-modal').addEventListener('click', () => modal.style.display = 'none');
    document.getElementById('btn-dismiss-asm').addEventListener('click', () => modal.style.display = 'none');
  }

  generateOamDataAssembly() {
    const lines = [];
    lines.push(`; =============================================================================`);
    lines.push(`; MOJAxMOJA WARS - OAM Meta-Sprite & Collision Bounding Box Tables`);
    lines.push(`; Generated by Web Character Editor`);
    lines.push(`; =============================================================================`);
    lines.push(``);
    lines.push(`.segment "RODATA"`);
    lines.push(``);

    this.characters.forEach(char => {
      lines.push(`; -----------------------------------------------------------------------------`);
      lines.push(`; Character: ${char.name} (${char.id})`);
      lines.push(`; Subpalette ID: ${char.paletteIdx}`);
      lines.push(`; -----------------------------------------------------------------------------`);
      
      Object.entries(char.animations).forEach(([state, frames]) => {
        lines.push(`meta_${char.id.toLowerCase()}_${state}:`);
        frames.forEach((fr, fIdx) => {
          lines.push(`  ; Frame #${fIdx} (Duration: ${fr.duration} frames)`);
          const sprites = fr.sprites || [];
          lines.push(`  .byte ${sprites.length}  ; Sprite count`);
          sprites.forEach(sp => {
            lines.push(`  .byte $${(sp.relY & 0xff).toString(16).padStart(2, '0')}, $${(sp.tileIndex & 0xff).toString(16).padStart(2, '0')}, $${(char.paletteIdx & 0x03).toString(16).padStart(2, '0')}, $${(sp.relX & 0xff).toString(16).padStart(2, '0')}  ; Y, Tile, Attr, X`);
          });
        });
        lines.push(``);
      });

      // Hitbox / Hurtbox AABB Tables (Center-relative half width and half height)
      const firstFrame = char.animations.idle ? char.animations.idle[0] : null;
      const hurt = firstFrame ? firstFrame.hurtbox : { w: 16, h: 16 };
      const hit = firstFrame ? firstFrame.hitbox : { w: 12, h: 12 };
      lines.push(`aabb_${char.id.toLowerCase()}:`);
      lines.push(`  .byte ${Math.round(hurt.w / 2)}, ${Math.round(hurt.h / 2)}  ; Hurtbox Half-W, Half-H`);
      lines.push(`  .byte ${Math.round(hit.w / 2)}, ${Math.round(hit.h / 2)}   ; Hitbox Half-W, Half-H`);
      lines.push(``);
    });

    return lines.join('\n');
  }

  generateChrDataAssembly() {
    const allTiles = [];
    const sigMap = new Map();

    this.characters.forEach(char => {
      Object.values(char.animations).forEach(frames => {
        frames.forEach(fr => {
          if (fr.tiles) {
            fr.tiles.forEach(t => {
              const sig = Array.from(t).join(',');
              if (!sigMap.has(sig)) {
                sigMap.set(sig, allTiles.length);
                allTiles.push(t);
              }
            });
          }
        });
      });
    });

    return formatChrAsAssembly(allTiles, "all_character_chr_tiles");
  }
}

// Instantiate on DOM load
if (document.readyState === 'loading') {
  window.addEventListener('DOMContentLoaded', () => {
    window.characterEditor = new CharacterEditorApp();
  });
} else {
  window.characterEditor = new CharacterEditorApp();
}

})(window);
