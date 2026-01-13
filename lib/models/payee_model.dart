// lib/models/payee_model.dart

class Payee {
  final int id;
  final String name;
  final String? contactPerson;
  final String? mobileNumber;

  Payee({
    required this.id,
    required this.name,
    this.contactPerson,
    this.mobileNumber,
  });

  // A factory constructor to create a Payee from a map (the data from Supabase)
  factory Payee.fromMap(Map<String, dynamic> map) {
    return Payee(
      id: map['id'],
      name: map['name'],
      contactPerson: map['contact_person'],
      mobileNumber: map['mobile_number'],
    );
  }
}
