### v0.3.1 (1/2/16)

- Hid some documentation on the internals of the library from the public API
  docs.
- Module scoped dependencies can no longer depend on test scoped
  dependencies.
- Fixed an issue where fixtures were marked as "function" scoped by default,
  rather than the "test" scoped expected in most places and stated in the docs.
- Fixed an issue where module scoped fixtures would be created on module start,
  but then also created whenever a test depended on them.

### v0.3.0 (19/1/16)

Added FixtureModules.  These are modules of fixtures that can be imported into
tests or other fixture modules.

ExUnitFixtures will automatically import any fixture modules that it finds
named `fixtures.exs`, and these will automatically be used by any tests level
with or further down in the directory heirarchy.  For example, we can now
create this directory heirarchy:

    tests/
        fixtures.exs
            defmodule GlobalFixtures do
              use ExUnitFixtures.FixtureModule

              deffixture db do
                create_db_conn()
              end
            end

        model_tests/
            fixtures.exs
                defmodule ModelFixtures do
                  use ExUnitFixtures.FixtureModule

                  deffixture user(db) do
                    user = %User{name: "Graeme"}
                    insert(db, user)
                    user
                  end
                end

            user_tests.exs
                defmodule UserTests do
                  use ExUnitFixtures

                  @tag fixtures: [:user]
                  test "user has name", context do
                    assert context.user.name == "Graeme"
                  end

### v0.2.0 (1/1/16)

- Added module scoped fixtures that are created at the start of a test module
  and teared down at the end.
- Added autouse fixtures that are added to every test automatically.
- Removed a bunch of stuff from the README in favour of pointing to hexdocs.pm

### v0.1.1 (26/12/15)

- Linter dependencies are now in the lint mix env, so not pulled into dependant
  apps.
- Defined package details for hex.pm release.

### v0.1.0 (26/12/15)

- Initial release.  Supports basic fixtures w/ dependencies in a single module.
