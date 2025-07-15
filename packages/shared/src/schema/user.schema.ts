import { z } from "zod/v4-mini";

export const UserSchema = z.object({
	id: z.string(),
	name: z.string().check(z.minLength(1), z.maxLength(200)),
});

export type User = z.infer<typeof UserSchema>
