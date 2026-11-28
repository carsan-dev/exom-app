import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Icons of the app, one constant per meaning (L5-D38,
/// docs/plans/rediseno-app-l5-contrato-v2.md).
///
/// Every glyph is Lucide (`lucide_icons_flutter` 4.0.3, MIT, regular weight).
/// Screens ask for a meaning (`ExomIcons.close`), never for a glyph, so a
/// glyph can change in one place. Material and Cupertino icons are not used in
/// `lib/` (guarded by `test/core/theme/exom_icons_sweep_test.dart`).
///
/// Stroke and size rule (verified by rendering at 16, 20 and 24 dp):
/// - The package ships a font per weight (`Lucide100` .. `Lucide600`, imported
///   from `lucide_icons_100.dart` .. `lucide_icons_600.dart`) and a regular
///   `Lucide` font. The regular font is the SVG default, a 2 px stroke on a
///   24 px grid, and is the one used here; `Lucide400` draws the same weight.
///   `Lucide300` (about 1.5 px) is thinner and is not used.
/// - The stroke scales with the size: 2 px at 24 dp, about 1.67 px at 20 dp and
///   about 1.33 px at 16 dp. Do not mix weights in a screen.
/// - 24 dp is the design size; 20 dp for icons inside rows and statuses;
///   16 dp only next to 13+ text. Colour comes from the theme token, never
///   from the glyph.
/// - Fonts are tree-shaken: only the glyphs referenced here reach the build.
///   Declaring a constant that no screen uses costs nothing.
abstract final class ExomIcons {
  /// Achievement (logro) of «Retos»: a medal, as in the sketch (`i-medal`).
  /// `trophy` already means the «Retos» section itself.
  static const IconData achievement = LucideIcons.medal;
  static const IconData add = LucideIcons.plus;
  static const IconData addPhoto = LucideIcons.imagePlus;
  static const IconData apple = LucideIcons.apple;
  static const IconData back = LucideIcons.arrowLeft;
  static const IconData barChart = LucideIcons.chartColumn;
  static const IconData bed = LucideIcons.bed;
  static const IconData block = LucideIcons.ban;
  static const IconData body = LucideIcons.personStanding;
  static const IconData calculate = LucideIcons.calculator;
  static const IconData calendar = LucideIcons.calendar;
  static const IconData calendarMonth = LucideIcons.calendarDays;
  static const IconData camera = LucideIcons.camera;
  static const IconData chat = LucideIcons.messageCircle;
  static const IconData chatRead = LucideIcons.messageSquareCheck;
  static const IconData chatUnread = LucideIcons.messageSquareDot;
  static const IconData check = LucideIcons.check;
  static const IconData cleaning = LucideIcons.brushCleaning;
  static const IconData close = LucideIcons.x;
  static const IconData coachVoice = LucideIcons.messageSquareQuote;
  static const IconData code = LucideIcons.code;
  static const IconData coffee = LucideIcons.coffee;
  static const IconData complete = LucideIcons.badgeCheck;
  static const IconData darkMode = LucideIcons.moon;
  static const IconData deleteForever = LucideIcons.trash2;
  static const IconData diet = LucideIcons.utensils;
  static const IconData done = LucideIcons.circleCheck;
  static const IconData editCalendar = LucideIcons.calendarCog;
  static const IconData editNote = LucideIcons.notebookPen;
  static const IconData email = LucideIcons.atSign;
  static const IconData error = LucideIcons.circleAlert;
  static const IconData event = LucideIcons.calendar;
  static const IconData eventBusy = LucideIcons.calendarX;
  static const IconData expand = LucideIcons.chevronDown;
  static const IconData explore = LucideIcons.compass;
  static const IconData fastForward = LucideIcons.fastForward;
  static const IconData feedback = LucideIcons.messageSquareWarning;
  static const IconData forward = LucideIcons.arrowRight;
  static const IconData gallery = LucideIcons.images;
  static const IconData grid = LucideIcons.layoutGrid;
  static const IconData height = LucideIcons.moveVertical;
  static const IconData help = LucideIcons.circleQuestionMark;
  static const IconData hide = LucideIcons.eyeOff;
  static const IconData home = LucideIcons.house;
  static const IconData image = LucideIcons.image;
  static const IconData inbox = LucideIcons.inbox;
  static const IconData info = LucideIcons.info;
  static const IconData language = LucideIcons.globe;
  static const IconData locked = LucideIcons.lock;
  static const IconData logout = LucideIcons.logOut;
  static const IconData meal = LucideIcons.utensils;
  static const IconData menu = LucideIcons.menu;
  static const IconData mood = LucideIcons.smile;
  static const IconData next = LucideIcons.chevronRight;
  static const IconData note = LucideIcons.stickyNote;
  static const IconData notes = LucideIcons.textAlignStart;
  static const IconData notifications = LucideIcons.bell;
  static const IconData notificationsActive = LucideIcons.bellRing;
  static const IconData notificationsOff = LucideIcons.bellOff;
  static const IconData offline = LucideIcons.cloudOff;
  static const IconData offlineSaved = LucideIcons.hardDrive;
  static const IconData openExternal = LucideIcons.externalLink;
  static const IconData pause = LucideIcons.pause;
  static const IconData pdf = LucideIcons.fileText;
  static const IconData phone = LucideIcons.smartphone;
  static const IconData play = LucideIcons.play;
  static const IconData previous = LucideIcons.chevronLeft;
  static const IconData print = LucideIcons.printer;
  static const IconData privacy = LucideIcons.shield;
  static const IconData profile = LucideIcons.user;
  static const IconData progress = LucideIcons.chartLine;
  static const IconData radioOff = LucideIcons.circle;
  static const IconData radioOn = LucideIcons.circleDot;
  static const IconData relax = LucideIcons.leaf;
  static const IconData remove = LucideIcons.minus;
  static const IconData repeat = LucideIcons.repeat;
  static const IconData reply = LucideIcons.reply;
  static const IconData retry = LucideIcons.rotateCw;
  static const IconData ruler = LucideIcons.ruler;
  static const IconData save = LucideIcons.save;
  static const IconData searchOff = LucideIcons.searchX;
  static const IconData send = LucideIcons.send;
  static const IconData settings = LucideIcons.settings;
  static const IconData share = LucideIcons.share2;
  static const IconData show = LucideIcons.eye;
  static const IconData sleep = LucideIcons.moon;
  static const IconData sparkles = LucideIcons.sparkles;
  static const IconData squareFoot = LucideIcons.triangleRight;
  static const IconData star = LucideIcons.star;
  static const IconData streak = LucideIcons.flame;
  static const IconData sun = LucideIcons.sun;
  static const IconData support = LucideIcons.headset;
  static const IconData swap = LucideIcons.arrowLeftRight;
  static const IconData syncProblem = LucideIcons.cloudAlert;
  static const IconData syncing = LucideIcons.cloudSync;
  static const IconData target = LucideIcons.target;
  static const IconData time = LucideIcons.clock;
  static const IconData tools = LucideIcons.wrench;
  static const IconData train = LucideIcons.dumbbell;
  static const IconData translate = LucideIcons.languages;
  static const IconData trendingUp = LucideIcons.trendingUp;
  static const IconData trophy = LucideIcons.trophy;
  static const IconData tune = LucideIcons.slidersHorizontal;
  static const IconData turnLeft = LucideIcons.cornerUpLeft;
  static const IconData turnRight = LucideIcons.cornerUpRight;
  static const IconData upload = LucideIcons.cloudUpload;
  static const IconData video = LucideIcons.video;
  static const IconData videoLibrary = LucideIcons.squarePlay;
  static const IconData volume = LucideIcons.volume2;
  static const IconData walk = LucideIcons.footprints;
  static const IconData water = LucideIcons.droplet;
  static const IconData weight = LucideIcons.weight;
  static const IconData wifiOff = LucideIcons.wifiOff;
  static const IconData zoomIn = LucideIcons.zoomIn;
}
