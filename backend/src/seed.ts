import bcrypt from "bcryptjs";
import dotenv from "dotenv";
import { PrismaClient } from "@prisma/client";

dotenv.config();

const prisma = new PrismaClient();

const siteContentSeed: { page: string; section: string; key: string; value: string; type: string; label: string }[] = [
  // --- HOMEPAGE ---
  { page: "home", section: "hero", key: "badge", value: "The Official Obroh Ancestry Datacenter", type: "text", label: "Hero Badge Text" },
  { page: "home", section: "hero", key: "title_line1", value: "Honouring", type: "text", label: "Hero Title Line 1" },
  { page: "home", section: "hero", key: "title_line2", value: "Our Legacy", type: "text", label: "Hero Title Line 2" },
  { page: "home", section: "hero", key: "subtitle", value: "Preserving the rich heritage of the Obroh dynasty — connecting generations past, present, and future through an unbroken chain of ancestral knowledge and familial bonds.", type: "text", label: "Hero Subtitle" },
  { page: "home", section: "hero", key: "cta_primary_text", value: "Explore the Dynasty", type: "text", label: "Primary CTA Text" },
  { page: "home", section: "hero", key: "cta_primary_href", value: "/family-tree", type: "text", label: "Primary CTA Link" },
  { page: "home", section: "hero", key: "cta_secondary_text", value: "Our Story", type: "text", label: "Secondary CTA Text" },
  { page: "home", section: "hero", key: "cta_secondary_href", value: "/about", type: "text", label: "Secondary CTA Link" },
  { page: "home", section: "stats", key: "stat_1_value", value: "200+", type: "text", label: "Stat 1 Value" },
  { page: "home", section: "stats", key: "stat_1_label", value: "Years of Heritage", type: "text", label: "Stat 1 Label" },
  { page: "home", section: "stats", key: "stat_2_value", value: "1,500+", type: "text", label: "Stat 2 Value" },
  { page: "home", section: "stats", key: "stat_2_label", value: "Family Members", type: "text", label: "Stat 2 Label" },
  { page: "home", section: "stats", key: "stat_3_value", value: "7", type: "text", label: "Stat 3 Value" },
  { page: "home", section: "stats", key: "stat_3_label", value: "Generations Tracked", type: "text", label: "Stat 3 Label" },
  { page: "home", section: "stats", key: "stat_4_value", value: "50+", type: "text", label: "Stat 4 Value" },
  { page: "home", section: "stats", key: "stat_4_label", value: "Family Branches", type: "text", label: "Stat 4 Label" },
  { page: "home", section: "heritage", key: "title", value: "Centuries of Heritage", type: "text", label: "Heritage Section Title" },
  { page: "home", section: "heritage", key: "subtitle", value: "The Obroh dynasty's story stretches across centuries — a rich tapestry of leadership, culture, and unwavering family bonds that have shaped communities and preserved our ancestral identity.", type: "text", label: "Heritage Subtitle" },
  { page: "home", section: "cta", key: "title", value: "Become Part of the Dynasty", type: "text", label: "CTA Section Title" },
  { page: "home", section: "cta", key: "subtitle", value: "Join the Obroh Ancestry Datacenter and ensure your story is preserved for generations to come. Every family member matters.", type: "text", label: "CTA Subtitle" },
  // --- ABOUT ---
  { page: "about", section: "hero", key: "title", value: "Our Story", type: "text", label: "About Hero Title" },
  { page: "about", section: "hero", key: "subtitle", value: "The Obroh Dynasty — a legacy of honour, unity, and cultural preservation spanning generations.", type: "text", label: "About Hero Subtitle" },
  { page: "about", section: "mission", key: "title", value: "Our Mission", type: "text", label: "Mission Title" },
  { page: "about", section: "mission", key: "description", value: "To preserve, protect, and promote the heritage of the Obroh dynasty through digital archiving, community building, and cultural education — ensuring that future generations inherit the full richness of their ancestral legacy.", type: "text", label: "Mission Description" },
  // --- CONTACT ---
  { page: "contact", section: "info", key: "email", value: "info@obroh.com", type: "text", label: "Contact Email" },
  { page: "contact", section: "info", key: "phone", value: "+234 800 000 0000", type: "text", label: "Contact Phone" },
  { page: "contact", section: "info", key: "location", value: "Obroh Ancestral Home, Delta State, Nigeria", type: "text", label: "Location" },
  { page: "contact", section: "info", key: "hours", value: "Mon – Fri: 9:00 AM – 5:00 PM WAT", type: "text", label: "Office Hours" },
  // --- LEGACY ---
  { page: "legacy", section: "hero", key: "title", value: "The Obroh Legacy", type: "text", label: "Legacy Hero Title" },
  { page: "legacy", section: "hero", key: "subtitle", value: "A chronicle of milestones, achievements, and the enduring spirit of the Obroh dynasty across generations.", type: "text", label: "Legacy Hero Subtitle" },
  // --- ELDERS ---
  { page: "elders", section: "hero", key: "title", value: "Council of Elders", type: "text", label: "Elders Hero Title" },
  { page: "elders", section: "hero", key: "subtitle", value: "The guardians of our tradition — leaders who guide the Obroh dynasty with wisdom, integrity, and an unwavering commitment to our heritage.", type: "text", label: "Elders Hero Subtitle" },
  // --- FAMILY TREE ---
  { page: "family-tree", section: "hero", key: "title", value: "The Obroh Family Tree", type: "text", label: "Family Tree Hero Title" },
  { page: "family-tree", section: "hero", key: "subtitle", value: "Explore the interconnected branches of the Obroh dynasty — a living map of our ancestral lineage.", type: "text", label: "Family Tree Hero Subtitle" },
  // --- KNOWLEDGE BASE ---
  { page: "knowledge-base", section: "hero", key: "title", value: "Knowledge Base", type: "text", label: "KB Hero Title" },
  { page: "knowledge-base", section: "hero", key: "subtitle", value: "A growing repository of ancestral wisdom, cultural practices, and historical records of the Obroh dynasty.", type: "text", label: "KB Hero Subtitle" },
];

async function seed() {
  try {
    // Seed admin user
    const existingAdmin = await prisma.user.findUnique({ where: { email: "admin@obroh.com" } });
    if (!existingAdmin) {
      const hashedPassword = await bcrypt.hash("Admin@Obroh2024", 12);
      await prisma.user.create({
        data: {
          firstName: "Obroh",
          lastName: "Admin",
          email: "admin@obroh.com",
          password: hashedPassword,
          role: "superadmin",
          status: "approved",
          location: "Delta State, Nigeria",
          branchId: null,
        },
      });
      console.log("Default admin created:");
      console.log("   Email: admin@obroh.com");
      console.log("   Password: Admin@Obroh2024");
    } else {
      console.log("Admin user already exists");
    }

    // Seed site content (upsert to avoid duplicates)
    let contentCreated = 0;
    for (const item of siteContentSeed) {
      const result = await prisma.siteContent.upsert({
        where: { page_section_key: { page: item.page, section: item.section, key: item.key } },
        update: {},
        create: item,
      });
      if (result) contentCreated++;
    }
    console.log(`${contentCreated} content items processed`);

    await prisma.$disconnect();
    console.log("\nSeed complete!");
    process.exit(0);
  } catch (error) {
    console.error("Seed failed:", error);
    await prisma.$disconnect();
    process.exit(1);
  }
}

seed();
