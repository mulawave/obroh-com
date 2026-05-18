import { randomUUID } from "crypto";
import { Prisma } from "@prisma/client";
import prisma from "./prisma";

function isRefreshTokenStoreUnavailable(error: unknown) {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    (error.code === "P2021" || error.code === "P2022")
  );
}

export async function createRefreshToken(userId: string, expiresInDays = 60) {
  const token = randomUUID();
  const expiresAt = new Date(Date.now() + expiresInDays * 24 * 60 * 60 * 1000);
  try {
    await prisma.refreshToken.create({
      data: { token, userId, expiresAt },
    });
  } catch (error) {
    if (isRefreshTokenStoreUnavailable(error)) {
      console.warn("Refresh token persistence unavailable; continuing without refresh token storage.", {
        prismaCode: (error as Prisma.PrismaClientKnownRequestError).code,
      });
      return null;
    }
    throw error;
  }
  return token;
}

export async function verifyRefreshToken(token: string) {
  let record;
  try {
    record = await prisma.refreshToken.findUnique({ where: { token } });
  } catch (error) {
    if (isRefreshTokenStoreUnavailable(error)) {
      return null;
    }
    throw error;
  }
  if (!record || record.expiresAt < new Date()) return null;
  return record.userId;
}

export async function revokeRefreshToken(token: string) {
  try {
    await prisma.refreshToken.deleteMany({ where: { token } });
  } catch (error) {
    if (isRefreshTokenStoreUnavailable(error)) {
      return;
    }
    throw error;
  }
}
