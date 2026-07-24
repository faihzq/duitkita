import 'package:flutter/material.dart';

/// Brand colours for a bank's icon tile.
/// [tile] is the chip/background colour, [icon] the foreground (icon) colour.
class BankBrand {
  final Color tile;
  final Color icon;
  const BankBrand({required this.tile, required this.icon});
}

/// Neutral fallback for unknown / unset banks.
const BankBrand kDefaultBankBrand = BankBrand(tile: Color(0xFF37474F), icon: Colors.white);

/// Keyed by a lowercase substring matched against the bank name.
/// Order matters only in that the first substring match wins.
const Map<String, BankBrand> _bankBrands = {
  'maybank': BankBrand(tile: Color(0xFFFFC72C), icon: Color(0xFF003B6F)),
  'cimb': BankBrand(tile: Color(0xFFEC1C24), icon: Colors.white),
  'public bank': BankBrand(tile: Color(0xFFC8102E), icon: Colors.white),
  'rhb': BankBrand(tile: Color(0xFF003DA5), icon: Colors.white),
  'hong leong': BankBrand(tile: Color(0xFF0D47A1), icon: Colors.white),
  'ambank': BankBrand(tile: Color(0xFF1A237E), icon: Colors.white),
  'bank islam': BankBrand(tile: Color(0xFF00695C), icon: Colors.white),
  'bsn': BankBrand(tile: Color(0xFFE65100), icon: Colors.white),
  'alliance': BankBrand(tile: Color(0xFFE03C31), icon: Colors.white),
  'affin': BankBrand(tile: Color(0xFF880E4F), icon: Colors.white),
  'bank rakyat': BankBrand(tile: Color(0xFF1B5E20), icon: Colors.white),
  'ocbc': BankBrand(tile: Color(0xFFE60012), icon: Colors.white),
  'uob': BankBrand(tile: Color(0xFF003D7C), icon: Colors.white),
  'standard chartered': BankBrand(tile: Color(0xFF0473EA), icon: Colors.white),
  'hsbc': BankBrand(tile: Color(0xFFDB0011), icon: Colors.white),
  'tabung': BankBrand(tile: Color(0xFF007A5E), icon: Colors.white),
};

/// Returns the [BankBrand] for [name], or [kDefaultBankBrand] if unknown/null.
BankBrand bankBrandFor(String? name) {
  if (name == null) return kDefaultBankBrand;
  final lower = name.toLowerCase();
  for (final e in _bankBrands.entries) {
    if (lower.contains(e.key)) return e.value;
  }
  return kDefaultBankBrand;
}
