/**
 * Create the first admin for the Jeya Staff app (or reset an admin's password):
 *
 *   npm run staff:create-admin
 *
 * Asks for the username, name and password in the terminal. The password is typed hidden and
 * only its scrypt hash is stored. After this, create every other account from the app
 * (Admin → Staff accounts), which hands out temporary passwords.
 */
import readline from 'node:readline';
import { Writable } from 'node:stream';
import { hashPassword, passwordProblem } from '../common/password';
import { closeDb, db } from '../db/client';
import { staffRepository } from '../modules/staff/staff.repository';
import { username as usernameSchema } from '../modules/staff/staff.schemas';

let muted = false;
const output = new Writable({
  write(chunk, encoding, callback) {
    if (!muted) process.stdout.write(chunk, encoding);
    callback();
  },
});
const rl = readline.createInterface({ input: process.stdin, output, terminal: true });

function ask(question: string, hidden = false): Promise<string> {
  return new Promise((resolve) => {
    process.stdout.write(question);
    muted = hidden;
    rl.question('', (answer) => {
      muted = false;
      if (hidden) process.stdout.write('\n');
      resolve(answer.trim());
    });
  });
}

async function main(): Promise<void> {
  if (!process.stdin.isTTY) throw new Error('Run this in a terminal (it needs to read the password hidden).');
  console.log('\nJeya Staff — create an admin account\n');

  const parsedUsername = usernameSchema.safeParse(await ask('Username (e.g. jeya.admin): '));
  if (!parsedUsername.success) throw new Error(parsedUsername.error.issues[0]?.message ?? 'Invalid username');
  const username = parsedUsername.data;
  const existing = await staffRepository.findByUsername(db, username);

  let name = existing?.name ?? '';
  if (existing) {
    const answer = await ask(`"${username}" already exists (${existing.role}). Set a new password and make it an active admin? (yes/no): `);
    if (answer.toLowerCase() !== 'yes') throw new Error('Nothing changed.');
  } else {
    name = await ask('Full name: ');
    if (name.length < 2) throw new Error('Name is too short');
  }

  const password = await ask('Password (min 8, letters + numbers; hidden): ', true);
  const problem = passwordProblem(password, username);
  if (problem) throw new Error(problem);
  if ((await ask('Type the password again (hidden): ', true)) !== password) throw new Error('Passwords did not match');

  const passwordHash = await hashPassword(password);
  if (existing) {
    await db.transaction(async (tx) => {
      await staffRepository.update(tx, existing.id, {
        passwordHash,
        role: 'admin',
        isActive: true,
        mustChangePassword: false,
        passwordChangedAt: new Date(),
        failedLoginCount: 0,
        lockedUntil: null,
      });
      await staffRepository.revokeAllSessions(tx, existing.id);
    });
    console.log(`\n✔ "${username}" is an active admin with the new password (signed out everywhere).`);
  } else {
    await staffRepository.insert(db, { username, name, role: 'admin', passwordHash, mustChangePassword: false, passwordChangedAt: new Date() });
    console.log(`\n✔ Admin "${username}" created. Sign in to the Jeya Staff app with it.`);
  }
}

main()
  .catch((error: unknown) => {
    console.error(`\n❌ ${error instanceof Error ? error.message : String(error)}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    rl.close();
    await closeDb();
  });
