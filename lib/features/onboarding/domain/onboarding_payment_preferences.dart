/// Unpaid onboarding billing preferences. No prices, card data, transaction
/// tokens, or subscription activation belong to this model.
class OnboardingPaymentPreferences {
  const OnboardingPaymentPreferences({
    this.billingCycle = 'monthly',
    this.preferredMethod = 'card',
    this.billingEmail,
    this.billingSchoolName,
    this.billingAddress,
    this.billingCity,
    this.billingCountryCode,
    this.billingPostalCode,
    this.taxIdentifier,
    this.skippedForTesting = false,
  });

  final String billingCycle;
  final String preferredMethod;
  final String? billingEmail, billingSchoolName, billingAddress;
  final String? billingCity, billingCountryCode, billingPostalCode;
  final String? taxIdentifier;
  final bool skippedForTesting;

  factory OnboardingPaymentPreferences.fromJson(
      Map<String, dynamic> value) => OnboardingPaymentPreferences(
    billingCycle: (value['billing_cycle'] as String?) ?? 'monthly',
    preferredMethod: (value['preferred_method'] as String?) ?? 'card',
    billingEmail: value['billing_email'] as String?,
    billingSchoolName: value['billing_school_name'] as String?,
    billingAddress: value['billing_address'] as String?,
    billingCity: value['billing_city'] as String?,
    billingCountryCode: value['billing_country_code'] as String?,
    billingPostalCode: value['billing_postal_code'] as String?,
    taxIdentifier: value['tax_identifier'] as String?,
    skippedForTesting:
      value['test_flow_state'] == 'skipped_for_testing',
  );

  /// Exactly these fields are safe for Supabase persistence.
  /// NEVER add a primary account number, expiry, CVV, or secret token.
  Map<String, dynamic> toJson() => {
    'billing_cycle': billingCycle,
    'preferred_method': preferredMethod,
    'billing_email': billingEmail,
    'billing_school_name': billingSchoolName,
    'billing_address': billingAddress,
    'billing_city': billingCity,
    'billing_country_code': billingCountryCode,
    'billing_postal_code': billingPostalCode,
    'tax_identifier': taxIdentifier,
    'test_flow_state': skippedForTesting
        ? 'skipped_for_testing' : 'preferences_only',
  };

  List<String> validate() {
    final errors = <String>[];
    if (!['monthly','annual'].contains(billingCycle)) {
      errors.add('Choose a valid billing cycle.');
    }
    if (!['card','bank_transfer','wallet'].contains(preferredMethod)) {
      errors.add('Choose a valid payment method.');
    }
    if (billingEmail != null && billingEmail!.trim().isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
            .hasMatch(billingEmail!.trim())) {
      errors.add('Enter a valid billing email.');
    }
    if (billingCountryCode != null &&
        billingCountryCode!.isNotEmpty &&
        !RegExp(r'^[A-Z]{2}$').hasMatch(billingCountryCode!)) {
      errors.add('Country must be a two-letter ISO code.');
    }
    final lengths = <(String?,int)>[
      (billingEmail,254), (billingSchoolName,220),
      (billingAddress,500), (billingCity,120),
      (billingPostalCode,32), (taxIdentifier,64),
    ];
    for (final field in lengths) {
      if (field.$1 != null && field.$1!.length > field.$2) {
        errors.add('Billing details contain a field that is too long.');
        break;
      }
    }
    return errors;
  }
}
