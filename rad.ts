import type { Task, Tasks } from "https://deno.land/x/rad/src/mod.ts";

const build: Task = `gleam build`;
const clean: Task = `rm -rf src/foo* src/internal/foo* src/bar* src/internal/bar*`;
const format: Task = `gleam format`;

const gleamTest: Task = {
  dependsOn: [clean],
  fn: async (toolkit) => {
    const { fs, path, logger, Deno, sh, task } = toolkit;
    await sh(`gleam test`);
  },
};

const test: Task = {
  dependsOn: [gleamTest, clean],
  // fn: async (toolkit) => {
  //   const { fs, path, logger, Deno, sh, task } = toolkit;
  //   await sh(`gleam test`);
  // },
};

export const tasks: Tasks = {
  clean,
  build,
  b: build,
  format,
  f: format,
  gleamTest,
  gt: gleamTest,
  test,
  t: test,
};
