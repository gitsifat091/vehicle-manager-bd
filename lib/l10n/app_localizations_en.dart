// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Vehicle Manager Bangladesh';

  @override
  String get navMap => 'Map';

  @override
  String get navGarage => 'Garage';

  @override
  String get navFinance => 'Finance';

  @override
  String get navSettings => 'Settings';

  @override
  String get comingLater => 'This screen comes in a later update.';

  @override
  String cashLine(String amount) {
    return 'Cash: $amount';
  }

  @override
  String turboBadge(String speed) {
    return 'Turbo ${speed}x';
  }

  @override
  String get newGameTitle => 'Start your company';

  @override
  String newGameIntro(String cash, String vehicle) {
    return 'You start with $cash and one free $vehicle. Send it to work and reinvest what it earns.';
  }

  @override
  String get companyNameLabel => 'Company name';

  @override
  String get companyNameHint => 'For example: Padma Transport';

  @override
  String get companyNameRequired => 'Enter a company name';

  @override
  String get startGameButton => 'Start';

  @override
  String get garageVehiclesTitle => 'Vehicles';

  @override
  String garageSlotsLine(String used, String total) {
    return '$used of $total garage slots used';
  }

  @override
  String get vehicleStatusIdle => 'Not assigned';

  @override
  String get vehicleStatusOnTheRoad => 'On the road';

  @override
  String get vehicleStatusWaiting => 'Waiting for demand';

  @override
  String get vehicleStatusReady => 'Ready to go';

  @override
  String vehicleRouteLine(String route, String cargo) {
    return '$route, $cargo';
  }

  @override
  String vehicleArrivesIn(String time) {
    return 'Arrives in $time';
  }

  @override
  String vehicleDepartsIn(String time) {
    return 'Goes again in $time';
  }

  @override
  String get tempStartWorking => 'Start working (temporary)';

  @override
  String vehicleName(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'tier1': 'Sonar Van',
      'tier2': 'Bijli Cargo',
      'tier3': 'Tuntuni Mini',
      'tier4': 'Sathi Plus',
      'tier5': 'Meghna 14',
      'tier6': 'Jamuna Open',
      'tier7': 'Karnaphuli 20',
      'tier8': 'Himaloy Reefer',
      'tier9': 'Pahari Tipper',
      'tier10': 'Telrani',
      'tier11': 'Bongo Mover 40',
      'tier12': 'Hati Lowbed',
      'other': 'Vehicle',
    });
    return '$_temp0';
  }

  @override
  String routeName(String route) {
    String _temp0 = intl.Intl.selectLogic(route, {
      'm01': 'Kawran Bazar to nearby shops',
      'm02': 'Dhaka neighbourhood delivery',
      'r01': 'Tejgaon to Dhaka city',
      'r02': 'Dhaka to Narayanganj',
      'r03': 'Dhaka to Gazipur',
      'r04': 'Dhaka to Cumilla',
      'r05': 'Dhaka to Chattogram Port',
      'r06': 'Gazipur to Chattogram Port',
      'r07': 'Dhaka to Sylhet',
      'r08': 'Dhaka to Bogura',
      'r09': 'Dhaka to Rangpur',
      'r10': 'Dhaka to Khulna via Padma Bridge',
      'r11': 'Dhaka to Khulna via Paturia ferry',
      'r12': 'Dhaka to Benapole',
      'r13': 'Chattogram Port to Cumilla',
      'r14': 'Narayanganj to Dhaka building sites',
      'other': 'Route',
    });
    return '$_temp0';
  }

  @override
  String cargoName(String cargo) {
    String _temp0 = intl.Intl.selectLogic(cargo, {
      'marketGoods': 'Market goods',
      'parcels': 'Parcels',
      'generalDry': 'General dry goods',
      'vegetables': 'Vegetables',
      'garments': 'Garments',
      'rice': 'Rice',
      'cementAndRod': 'Cement and rod',
      'sandAndStone': 'Sand and stone',
      'fish': 'Fish',
      'fuel': 'Fuel',
      'containers': 'Containers',
      'heavyMachinery': 'Heavy machinery',
      'other': 'Cargo',
    });
    return '$_temp0';
  }
}
