import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// The name of the app, shown in the title bar and the task switcher.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Manager Bangladesh'**
  String get appTitle;

  /// Navigation item that opens the map of Bangladesh with the routes.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// Navigation item that opens the list of the player's vehicles.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get navGarage;

  /// Navigation item that opens income, costs and profit.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get navFinance;

  /// Navigation item that opens language, theme and new game.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Placeholder text on a screen that is not built yet.
  ///
  /// In en, this message translates to:
  /// **'This screen comes in a later update.'**
  String get comingLater;

  /// The company's cash, shown under the company name at the top of every screen. The amount is already formatted as money.
  ///
  /// In en, this message translates to:
  /// **'Cash: {amount}'**
  String cashLine(String amount);

  /// Small badge at the top of the screen during Turbo Start: how many times faster than normal the game runs. The speed is already formatted.
  ///
  /// In en, this message translates to:
  /// **'Turbo {speed}x'**
  String turboBadge(String speed);

  /// Heading of the new-game screen.
  ///
  /// In en, this message translates to:
  /// **'Start your company'**
  String get newGameTitle;

  /// Explains the starting position on the new-game screen. Both values are already formatted.
  ///
  /// In en, this message translates to:
  /// **'You start with {cash} and one free {vehicle}. Send it to work and reinvest what it earns.'**
  String newGameIntro(String cash, String vehicle);

  /// Label of the company name field.
  ///
  /// In en, this message translates to:
  /// **'Company name'**
  String get companyNameLabel;

  /// Example shown inside the empty company name field.
  ///
  /// In en, this message translates to:
  /// **'For example: Padma Transport'**
  String get companyNameHint;

  /// Error under the company name field when it is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter a company name'**
  String get companyNameRequired;

  /// Button that creates the company and begins the game.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startGameButton;

  /// Heading of the list of the player's vehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get garageVehiclesTitle;

  /// How many of the garage's vehicle slots are taken. Both numbers are already formatted.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total} garage slots used'**
  String garageSlotsLine(String used, String total);

  /// Status of a vehicle that has no route.
  ///
  /// In en, this message translates to:
  /// **'Not assigned'**
  String get vehicleStatusIdle;

  /// Status of a vehicle that is making a trip.
  ///
  /// In en, this message translates to:
  /// **'On the road'**
  String get vehicleStatusOnTheRoad;

  /// Status of a vehicle whose route has no cargo left today. It goes again when the next game day starts.
  ///
  /// In en, this message translates to:
  /// **'Waiting for demand'**
  String get vehicleStatusWaiting;

  /// Status of an assigned vehicle that can depart now.
  ///
  /// In en, this message translates to:
  /// **'Ready to go'**
  String get vehicleStatusReady;

  /// The route and cargo a vehicle works on. Both are already translated names.
  ///
  /// In en, this message translates to:
  /// **'{route}, {cargo}'**
  String vehicleRouteLine(String route, String cargo);

  /// Time left on a trip. The time is already formatted as a timer.
  ///
  /// In en, this message translates to:
  /// **'Arrives in {time}'**
  String vehicleArrivesIn(String time);

  /// Shown instead of the time left once a trip has reached its destination and is about to be paid out (a few seconds).
  ///
  /// In en, this message translates to:
  /// **'Arriving'**
  String get vehicleArriving;

  /// Time until a vehicle waiting for demand departs. The time is already formatted as a timer.
  ///
  /// In en, this message translates to:
  /// **'Goes again in {time}'**
  String vehicleDepartsIn(String time);

  /// Shown on the sell screen for the free vehicle the company started with, which sells for a fixed amount instead of a share of its price. The amount is already formatted as money.
  ///
  /// In en, this message translates to:
  /// **'This is your company\'s starter vehicle. It sells for a fixed {amount}.'**
  String starterSaleNote(String amount);

  /// Temporary button on the garage screen that sends an idle vehicle on the first route. Removed when the assign-route screen exists.
  ///
  /// In en, this message translates to:
  /// **'Start working (temporary)'**
  String get tempStartWorking;

  /// On a garage tile: what the vehicle's job is expected to earn per real hour at normal speed. The amount is already formatted as money.
  ///
  /// In en, this message translates to:
  /// **'Expected profit {amount} an hour'**
  String vehicleProfitPerHour(String amount);

  /// Button at the top of the vehicle detail that returns to the garage list.
  ///
  /// In en, this message translates to:
  /// **'Back to garage'**
  String get vehicleDetailBack;

  /// Under the vehicle name in the detail: its size tier. The number is already formatted.
  ///
  /// In en, this message translates to:
  /// **'Tier {tier}'**
  String vehicleTierLine(String tier);

  /// In the vehicle detail: the vehicle was unassigned while on a trip. The trip still finishes and is paid.
  ///
  /// In en, this message translates to:
  /// **'Not assigned any more. It comes home after this trip.'**
  String get vehicleGoesHomeNote;

  /// Button in the vehicle detail that takes the route away. A trip on the road still finishes.
  ///
  /// In en, this message translates to:
  /// **'Unassign'**
  String get vehicleUnassignButton;

  /// Heading of the vehicle detail section with the expected profit and the sale value.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get vehicleEarningsTitle;

  /// Label of the expected profit per real hour of the vehicle's job.
  ///
  /// In en, this message translates to:
  /// **'Expected profit per hour'**
  String get vehicleProfitPerHourLabel;

  /// Explains that the expected profit per hour is at 1x speed.
  ///
  /// In en, this message translates to:
  /// **'At normal speed. Turbo Start makes the hours pass faster.'**
  String get vehicleProfitPerHourNote;

  /// Label of what selling the vehicle would pay.
  ///
  /// In en, this message translates to:
  /// **'Sells for'**
  String get vehicleSaleValueLabel;

  /// Heading of the vehicle detail section with the money of the trip on the road.
  ///
  /// In en, this message translates to:
  /// **'Current trip'**
  String get vehicleCurrentTripTitle;

  /// Label of the tons a trip carries.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get tripLoadLabel;

  /// Label of what a trip is paid.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get tripRevenueLabel;

  /// Label of the fuel or energy cost of a trip.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get costEnergyLabel;

  /// Label of the bridge and road tolls of a trip.
  ///
  /// In en, this message translates to:
  /// **'Tolls'**
  String get costTollLabel;

  /// Label of the driver and helper wages of a trip.
  ///
  /// In en, this message translates to:
  /// **'Crew'**
  String get costCrewLabel;

  /// Label of the wear and repair cost of a trip.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get costMaintenanceLabel;

  /// Label of the expected overload fines of a trip on the road. The real fines are rolled when it arrives.
  ///
  /// In en, this message translates to:
  /// **'Fines (expected)'**
  String get costFinesExpectedLabel;

  /// Label of the expected accident cost of a trip on the road. Whether an accident happens is rolled when it arrives.
  ///
  /// In en, this message translates to:
  /// **'Accident risk (expected)'**
  String get costAccidentExpectedLabel;

  /// Label of the expected profit of a trip on the road.
  ///
  /// In en, this message translates to:
  /// **'Profit (expected)'**
  String get tripProfitExpectedLabel;

  /// Heading of the list of the vehicle's last finished trips.
  ///
  /// In en, this message translates to:
  /// **'Recent trips'**
  String get vehicleRecentTripsTitle;

  /// Under the recent trips heading: older trips are not listed.
  ///
  /// In en, this message translates to:
  /// **'Only the most recent trips are kept.'**
  String get vehicleRecentTripsNote;

  /// Shown when the vehicle has no finished trip to list.
  ///
  /// In en, this message translates to:
  /// **'No finished trips yet.'**
  String get vehicleRecentTripsNone;

  /// Heading of the vehicle detail section with price, payload and speed.
  ///
  /// In en, this message translates to:
  /// **'Specifications'**
  String get vehicleSpecsTitle;

  /// Label of the vehicle's purchase price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get specPriceLabel;

  /// Label of the tons the vehicle may carry by law.
  ///
  /// In en, this message translates to:
  /// **'Legal payload'**
  String get specLegalPayloadLabel;

  /// Label of the most tons the vehicle can physically carry, overloaded.
  ///
  /// In en, this message translates to:
  /// **'Maximum load'**
  String get specMaxLoadLabel;

  /// Label of the vehicle's average road speed.
  ///
  /// In en, this message translates to:
  /// **'Average speed'**
  String get specSpeedLabel;

  /// Label of how far the vehicle goes on one litre of diesel.
  ///
  /// In en, this message translates to:
  /// **'Mileage'**
  String get specMileageLabel;

  /// Label of the energy cost per km of a vehicle that does not run on diesel.
  ///
  /// In en, this message translates to:
  /// **'Energy cost'**
  String get specEnergyCostLabel;

  /// A weight in tons. The number is already formatted.
  ///
  /// In en, this message translates to:
  /// **'{tons} t'**
  String tonsValue(String tons);

  /// A speed in kilometres per hour. The number is already formatted.
  ///
  /// In en, this message translates to:
  /// **'{speed} km/h'**
  String speedValue(String speed);

  /// Diesel mileage. The number is already formatted.
  ///
  /// In en, this message translates to:
  /// **'{km} km per litre'**
  String mileageValue(String km);

  /// A cost per kilometre in Taka. The number is already formatted, without the currency sign.
  ///
  /// In en, this message translates to:
  /// **'Tk {amount} per km'**
  String perKmValue(String amount);

  /// The fictional name of a vehicle tier. The tier is 'tier' followed by the number, for example tier4.
  ///
  /// In en, this message translates to:
  /// **'{tier, select, tier1{Sonar Van} tier2{Bijli Cargo} tier3{Tuntuni Mini} tier4{Sathi Plus} tier5{Meghna 14} tier6{Jamuna Open} tier7{Karnaphuli 20} tier8{Himaloy Reefer} tier9{Pahari Tipper} tier10{Telrani} tier11{Bongo Mover 40} tier12{Hati Lowbed} other{Vehicle}}'**
  String vehicleName(String tier);

  /// The name of a route. The route is the route id in lower case, for example r01.
  ///
  /// In en, this message translates to:
  /// **'{route, select, m01{Kawran Bazar to nearby shops} m02{Dhaka neighbourhood delivery} r01{Tejgaon to Dhaka city} r02{Dhaka to Narayanganj} r03{Dhaka to Gazipur} r04{Dhaka to Cumilla} r05{Dhaka to Chattogram Port} r06{Gazipur to Chattogram Port} r07{Dhaka to Sylhet} r08{Dhaka to Bogura} r09{Dhaka to Rangpur} r10{Dhaka to Khulna via Padma Bridge} r11{Dhaka to Khulna via Paturia ferry} r12{Dhaka to Benapole} r13{Chattogram Port to Cumilla} r14{Narayanganj to Dhaka building sites} other{Route}}'**
  String routeName(String route);

  /// The name of a cargo type. The cargo is the English cargo name in camel case, for example generalDry.
  ///
  /// In en, this message translates to:
  /// **'{cargo, select, marketGoods{Market goods} parcels{Parcels} generalDry{General dry goods} vegetables{Vegetables} garments{Garments} rice{Rice} cementAndRod{Cement and rod} sandAndStone{Sand and stone} fish{Fish} fuel{Fuel} containers{Containers} heavyMachinery{Heavy machinery} other{Cargo}}'**
  String cargoName(String cargo);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
