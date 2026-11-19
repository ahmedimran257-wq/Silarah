import 'package:flutter/widgets.dart';

/// One way to write a member's name everywhere.
///
/// The server sends the full surname only to an active match; everyone else
/// gets its first letter. An initial is written with a full stop
/// ("Abdul A.") so it reads as deliberate, and a full surname is written as
/// it is ("Abdul Aziz").
String memberDisplayName(String firstName, String surname) {
  final first = firstName.trim();
  final last = surname.trim();
  if (last.isEmpty) return first;
  if (first.isEmpty) return last;
  final isInitial = last.characters.length == 1;
  return isInitial ? '$first ${last.toUpperCase()}.' : '$first $last';
}

/// True when only the surname's initial is known, so the profile can say
/// that the full surname is shared after a match.
bool isSurnameInitialOnly(String surname) =>
    surname.trim().characters.length == 1;
