library;

class CompanyProfileStore {
  CompanyProfileStore._();

  static bool isCompany = false;

  static String companyName = '';
  static String orgType = 'Startup';
  static int? foundingYear;
  static String website = '';
  static String description = '';
  static List<String> cultureValues = [];
  static String cultureText = '';
  static Map<String, bool> perks = {};
  static List<String> profilesSought = [];
  static String teamSize = '';
  static List<String> techStack = [];
  static String modality = 'Remoto';
  static String location = '';
  static List<String> industries = [];

  static void store({
    required String name,
    required String orgType,
    int? year,
    String? website,
    required String description,
    required List<String> values,
    String? cultureText,
    required Map<String, bool> perks,
    required List<String> profiles,
    required String teamSize,
    required List<String> techStack,
    required String modality,
    required String location,
    required List<String> industries,
  }) {
    isCompany = true;
    companyName = name;
    CompanyProfileStore.orgType = orgType;
    foundingYear = year;
    CompanyProfileStore.website = website ?? '';
    CompanyProfileStore.description = description;
    cultureValues = List.from(values);
    CompanyProfileStore.cultureText = cultureText ?? '';
    CompanyProfileStore.perks = Map.from(perks);
    profilesSought = List.from(profiles);
    CompanyProfileStore.teamSize = teamSize;
    CompanyProfileStore.techStack = List.from(techStack);
    CompanyProfileStore.modality = modality;
    CompanyProfileStore.location = location;
    CompanyProfileStore.industries = List.from(industries);
  }

  static List<String> get activePerks =>
      perks.entries.where((e) => e.value).map((e) => e.key).toList();
}
