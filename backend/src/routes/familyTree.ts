import { Router } from "express";
import prisma from "../lib/prisma";
import { authenticate, requireApproved, AuthRequest } from "../middleware/auth";
import { createMemoryUpload, createObjectName, saveUploadedFile } from "../lib/uploadStorage";

const router = Router();
const auth: any[] = [authenticate as any, requireApproved as any];

const upload = createMemoryUpload({
  errorMessage: "Only image files are allowed",
  fileSize: 5 * 1024 * 1024,
  accept: (mimetype, originalName) => {
    const allowedTypes = /jpeg|jpg|png|gif|webp/;
    return allowedTypes.test(mimetype) && allowedTypes.test(originalName.toLowerCase());
  },
});

// POST /api/family-tree/upload - Upload branch image
router.post("/upload", ...auth, upload.single("image"), async (req: AuthRequest, res) => {
  if (!req.file) {
    res.status(400).json({ error: "No file uploaded" });
    return;
  }

  const imageUrl = await saveUploadedFile(
    req.file,
    createObjectName("branches", req.file.originalname, req.user?.id),
  );
  res.json({ imageUrl });
});

interface TreeNode {
  id: string;
  name: string;
  description: string | null;
  image: string | null;
  patriarch?: {
    id: string;
    firstName: string;
    lastName: string;
    profileImage: string | null;
  };
  level: number;
  children: TreeNode[];
  memberCount: number;
  branchCount: number;
}

// Helper function to count total branches recursively
function countBranches(node: TreeNode): number {
  let count = node.children.length;
  for (const child of node.children) {
    count += countBranches(child);
  }
  return count;
}

// Helper function to build tree recursively
async function buildTree(branchId: string | null, level: number, maxDepth?: number): Promise<TreeNode[]> {
  if (maxDepth !== undefined && level >= maxDepth) {
    return [];
  }

  const branches = await prisma.familyBranch.findMany({
    where: { parentId: branchId },
    include: {
      patriarch: {
        select: {
          id: true,
          firstName: true,
          lastName: true,
          profileImage: true,
        },
      },
      _count: {
        select: { members: true },
      },
    },
    orderBy: { name: "asc" },
    take: 100,
  });

  const nodes: TreeNode[] = [];
  for (const branch of branches) {
    const children = await buildTree(branch.id, level + 1, maxDepth);
    const node: TreeNode = {
      id: branch.id,
      name: branch.name,
      description: branch.description,
      image: branch.image,
      patriarch: branch.patriarch || undefined,
      level: branch.level,
      memberCount: branch._count.members,
      children,
      branchCount: children.length,
    };
    // Calculate total branch count including all descendants
    node.branchCount = countBranches(node);
    nodes.push(node);
  }
  return nodes;
}

// GET /api/family-tree/public - Get public family tree (main branch + direct children only)
router.get("/public", async (_req, res) => {
  try {
    const tree = await buildTree(null, 0, 2); // maxDepth=2 includes level 0 (main) and level 1 (direct children)
    res.json({ tree });
  } catch (err) {
    console.error("Public family tree fetch error:", err);
    res.status(500).json({ error: "Failed to load family tree" });
  }
});

// GET /api/family-tree/registration-branches - Public branch list for registration forms
router.get("/registration-branches", async (_req, res) => {
  try {
    const branches = await prisma.familyBranch.findMany({
      select: {
        id: true,
        name: true,
        parentId: true,
        level: true,
      },
      orderBy: [{ level: "asc" }, { name: "asc" }],
      take: 1000,
    });
    res.json({ branches, total: branches.length });
  } catch (err) {
    console.error("Registration branches fetch error:", err);
    res.status(500).json({ error: "Failed to load registration branches" });
  }
});

// GET /api/family-tree - Get full family tree (authenticated users only)
router.get("/", ...auth, async (_req: AuthRequest, res) => {
  try {
    const tree = await buildTree(null, 0); // no maxDepth = full tree
    res.json({ tree });
  } catch (err) {
    console.error("Family tree fetch error:", err);
    res.status(500).json({ error: "Failed to load family tree" });
  }
});

// GET /api/family-tree/branches - Get all branches (flat list)
router.get("/branches", ...auth, async (_req: AuthRequest, res) => {
  try {
    const branches = await prisma.familyBranch.findMany({
      include: {
        patriarch: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            profileImage: true,
          },
        },
        parent: {
          select: {
            id: true,
            name: true,
          },
        },
        _count: {
          select: { members: true, children: true },
        },
      },
      orderBy: [{ level: "asc" }, { name: "asc" }],
      take: 100,
    });
    res.json({ branches, total: branches.length });
  } catch (err) {
    console.error("Branches fetch error:", err);
    res.status(500).json({ error: "Failed to load branches" });
  }
});

// POST /api/family-tree/branches - Create a new branch
router.post("/branches", ...auth, async (req: AuthRequest, res) => {
  try {
    const { name, description, image, parentId, patriarchId } = req.body;

    if (!name) {
      res.status(400).json({ error: "Branch name is required" });
      return;
    }

    let level = 0;
    if (parentId) {
      const parentBranch = await prisma.familyBranch.findUnique({
        where: { id: parentId },
      });
      if (!parentBranch) {
        res.status(404).json({ error: "Parent branch not found" });
        return;
      }
      level = parentBranch.level + 1;
    }

    const branch = await prisma.familyBranch.create({
      data: {
        name,
        description,
        image,
        parentId,
        patriarchId,
        level,
      },
      include: {
        patriarch: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            profileImage: true,
          },
        },
      },
    });

    res.status(201).json(branch);
  } catch (err) {
    console.error("Create branch error:", err);
    res.status(500).json({ error: "Failed to create branch" });
  }
});

// PUT /api/family-tree/branches/:id - Update a branch
router.put("/branches/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const { name, description, image, patriarchId } = req.body;

    const branch = await prisma.familyBranch.update({
      where: { id },
      data: {
        name,
        description,
        image,
        patriarchId,
      },
      include: {
        patriarch: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            profileImage: true,
          },
        },
      },
    });

    res.json(branch);
  } catch (err) {
    console.error("Update branch error:", err);
    res.status(500).json({ error: "Failed to update branch" });
  }
});

// DELETE /api/family-tree/branches/:id - Delete a branch
router.delete("/branches/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);

    const children = await prisma.familyBranch.findMany({
      where: { parentId: id },
      take: 100,
    });
    if (children.length > 0) {
      res.status(400).json({ error: "Cannot delete branch with child branches. Delete children first." });
      return;
    }

    const members = await prisma.user.findMany({
      where: { branchId: id },
      take: 100,
    });
    if (members.length > 0) {
      res.status(400).json({ error: "Cannot delete branch with members. Reassign members first." });
      return;
    }

    await prisma.familyBranch.delete({ where: { id } });
    res.json({ message: "Branch deleted" });
  } catch (err) {
    console.error("Delete branch error:", err);
    res.status(500).json({ error: "Failed to delete branch" });
  }
});

// POST /api/family-tree/branches/:id/set-patriarch - Set patriarch for a branch
router.post("/branches/:id/set-patriarch", ...auth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const { userId } = req.body;

    if (!userId) {
      res.status(400).json({ error: "User ID is required" });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
    });
    if (!user) {
      res.status(404).json({ error: "User not found" });
      return;
    }

    await prisma.user.update({
      where: { id: userId },
      data: { branchId: id },
    });

    const branch = await prisma.familyBranch.update({
      where: { id },
      data: { patriarchId: userId },
      include: {
        patriarch: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            profileImage: true,
          },
        },
      },
    });

    res.json(branch);
  } catch (err) {
    console.error("Set patriarch error:", err);
    res.status(500).json({ error: "Failed to set patriarch" });
  }
});

// GET /api/family-tree/branches/:id/members - Get members of a branch
router.get("/branches/:id/members", ...auth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const members = await prisma.user.findMany({
      where: { branchId: id },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        profileImage: true,
        email: true,
        status: true,
      },
      orderBy: [{ lastName: "asc" }, { firstName: "asc" }],
      take: 100,
    });
    res.json({ members, total: members.length });
  } catch (err) {
    console.error("Branch members fetch error:", err);
    res.status(500).json({ error: "Failed to load branch members" });
  }
});

// POST /api/family-tree/members/:userId/branch - Assign user to branch
router.post("/members/:userId/branch", ...auth, async (req: AuthRequest, res) => {
  try {
    const userId = String(req.params.userId);
    const { branchId } = req.body;

    const user = await prisma.user.update({
      where: { id: userId },
      data: { branchId },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        branchId: true,
      },
    });

    res.json(user);
  } catch (err) {
    console.error("Assign member to branch error:", err);
    res.status(500).json({ error: "Failed to assign member to branch" });
  }
});

export default router;
