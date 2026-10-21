// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'ভেহিকেল ম্যানেজার বাংলাদেশ';

  @override
  String get noGameYet => 'এখনো কোনো খেলা শুরু হয়নি';

  @override
  String cashLine(String amount) {
    return 'নগদ: $amount';
  }

  @override
  String turboLine(String speed) {
    return 'টার্বো স্টার্টের গতি: $speed গুণ';
  }

  @override
  String get newGameTitle => 'আপনার কোম্পানি শুরু করুন';

  @override
  String newGameIntro(String cash, String vehicle) {
    return 'আপনি $cash আর একটি বিনামূল্যের $vehicle নিয়ে শুরু করছেন। এটিকে কাজে পাঠান আর আয় থেকে আবার বিনিয়োগ করুন।';
  }

  @override
  String get companyNameLabel => 'কোম্পানির নাম';

  @override
  String get companyNameHint => 'যেমন: পদ্মা ট্রান্সপোর্ট';

  @override
  String get companyNameRequired => 'কোম্পানির নাম লিখুন';

  @override
  String get startGameButton => 'শুরু করুন';

  @override
  String get homeVehiclesTitle => 'যানবাহন';

  @override
  String garageSlotsLine(String used, String total) {
    return 'গ্যারেজের $totalটি জায়গার মধ্যে $usedটি ভরা';
  }

  @override
  String get vehicleStatusIdle => 'কাজ দেওয়া হয়নি';

  @override
  String get vehicleStatusOnTheRoad => 'পথে আছে';

  @override
  String get vehicleStatusWaiting => 'চাহিদার অপেক্ষায়';

  @override
  String get vehicleStatusReady => 'যাত্রার জন্য প্রস্তুত';

  @override
  String vehicleRouteLine(String route, String cargo) {
    return '$route, $cargo';
  }

  @override
  String vehicleArrivesIn(String time) {
    return 'পৌঁছাতে বাকি $time';
  }

  @override
  String vehicleDepartsIn(String time) {
    return 'আবার ছাড়বে $time পরে';
  }

  @override
  String get tempStartWorking => 'কাজে পাঠান (সাময়িক)';

  @override
  String vehicleName(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'tier1': 'সোনার ভ্যান',
      'tier2': 'বিজলি কার্গো',
      'tier3': 'টুনটুনি মিনি',
      'tier4': 'সাথী প্লাস',
      'tier5': 'মেঘনা ১৪',
      'tier6': 'যমুনা খোলা ট্রাক',
      'tier7': 'কর্ণফুলী ২০',
      'tier8': 'হিমালয় রিফার',
      'tier9': 'পাহাড়ি টিপার',
      'tier10': 'তেলরানী',
      'tier11': 'বঙ্গমুভার ৪০',
      'tier12': 'হাতি লো-বেড',
      'other': 'যানবাহন',
    });
    return '$_temp0';
  }

  @override
  String routeName(String route) {
    String _temp0 = intl.Intl.selectLogic(route, {
      'm01': 'কাওরান বাজার থেকে কাছের দোকান',
      'm02': 'ঢাকার পাড়ায় ডেলিভারি',
      'r01': 'তেজগাঁও থেকে ঢাকা শহর',
      'r02': 'ঢাকা থেকে নারায়ণগঞ্জ',
      'r03': 'ঢাকা থেকে গাজীপুর',
      'r04': 'ঢাকা থেকে কুমিল্লা',
      'r05': 'ঢাকা থেকে চট্টগ্রাম বন্দর',
      'r06': 'গাজীপুর থেকে চট্টগ্রাম বন্দর',
      'r07': 'ঢাকা থেকে সিলেট',
      'r08': 'ঢাকা থেকে বগুড়া',
      'r09': 'ঢাকা থেকে রংপুর',
      'r10': 'ঢাকা থেকে খুলনা, পদ্মা সেতু হয়ে',
      'r11': 'ঢাকা থেকে খুলনা, পাটুরিয়া ফেরি হয়ে',
      'r12': 'ঢাকা থেকে বেনাপোল',
      'r13': 'চট্টগ্রাম বন্দর থেকে কুমিল্লা',
      'r14': 'নারায়ণগঞ্জ থেকে ঢাকার নির্মাণস্থল',
      'other': 'রুট',
    });
    return '$_temp0';
  }

  @override
  String cargoName(String cargo) {
    String _temp0 = intl.Intl.selectLogic(cargo, {
      'marketGoods': 'বাজারের মাল',
      'parcels': 'পার্সেল',
      'generalDry': 'সাধারণ শুকনো মাল',
      'vegetables': 'সবজি',
      'garments': 'পোশাক',
      'rice': 'চাল',
      'cementAndRod': 'সিমেন্ট ও রড',
      'sandAndStone': 'বালু ও পাথর',
      'fish': 'মাছ',
      'fuel': 'জ্বালানি',
      'containers': 'কনটেইনার',
      'heavyMachinery': 'ভারী যন্ত্র',
      'other': 'মাল',
    });
    return '$_temp0';
  }
}
