defmodule Husky.Task.InstallTest do
  import ExUnit.CaptureIO
  use ExUnit.Case, async: false
  require Husky.Util
  alias Mix.Tasks.Husky.Install
  alias Husky.{TestHelper, Util}
  require TestHelper

  @install_message """
  ... running 'husky.install' task
  successfully installed husky scripts
  """

  setup do
    # Delete all scripts before each test in sandbox
    TestHelper.initialize_local()
    :ok
  end

  describe "Mix.Tasks.Husky.Install.run" do
    test "should create a file fore each supported git hook" do
      scripts = Util.git_hooks_directory() |> File.ls!() |> Enum.sort()
      assert Enum.all?(scripts, fn e -> e in TestHelper.git_default_scripts() end)

      assert @install_message == capture_io(&Install.run/0)

      scripts = Util.git_hooks_directory() |> File.ls!() |> Enum.sort()
      n_scripts = length(scripts)
      assert Enum.all?(scripts, fn e -> e in TestHelper.all_scripts() end)

      assert length(TestHelper.all_scripts()) == n_scripts ||
               length(TestHelper.all_scripts()) - 1 == n_scripts
    end

    test "should create scripts with the correct content" do
      assert @install_message == capture_io(&Install.run/0)

      content =
        Util.git_hooks_directory()
        |> Path.join("pre-commit")
        |> File.read!()

      assert """
             #!/usr/bin/env sh
             # #{Util.app()}
             # #{Util.version()} #{:os.type() |> Tuple.to_list() |> Enum.map(&Atom.to_string/1) |> Enum.map(&(&1 <> " "))}
             export MIX_ENV=test && cd ../../
             SCRIPT_PATH="./priv/husky"
             HOOK_NAME=`basename "$0"`
             GIT_PARAMS="$*"

             if [ "${HUSKY_SKIP_HOOKS}" = "true" ] || [ "${HUSKY_SKIP_HOOKS}" = "1" ]; then
               printf "\\033[33mhusky > skipping git hooks because environment variable HUSKY_SKIP_HOOKS is set...\\033[0m\n"
               exit 0
             fi

             if [ "${HUSKY_DEBUG}" = "true" ]; then
               echo "husky:debug $HOOK_NAME hook started..."
             fi

             if [ -f $SCRIPT_PATH ]; then
               $SCRIPT_PATH $HOOK_NAME "$GIT_PARAMS"
             else
               echo "Can not find Husky escript. Skipping $HOOK_NAME hook"
               echo "You can reinstall husky by running mix husky.install"
             fi
             """ == content
    end
  end

  describe "Mix.Tasks.Husky.Install.__after_compile__" do
    test "should create a file for each supported git hook" do
      scripts = Util.git_hooks_directory() |> File.ls!() |> Enum.sort()
      assert Enum.all?(scripts, fn e -> e in TestHelper.git_default_scripts() end)

      assert @install_message ==
               capture_io(fn ->
                 Install.__after_compile__(nil, nil)
               end)

      scripts = Util.git_hooks_directory() |> File.ls!() |> Enum.sort()
      n_scripts = length(scripts)
      assert Enum.all?(scripts, fn e -> e in TestHelper.all_scripts() end)

      assert length(TestHelper.all_scripts()) == n_scripts ||
               length(TestHelper.all_scripts()) - 1 == n_scripts
    end

    test "should respect the HUSKY_SKIP_INSTALL flag and not run Install.run/0 if it is set to true" do
      System.put_env("HUSKY_SKIP_INSTALL", "true")
      Install.__after_compile__(nil, nil)
      refute Util.git_hooks_directory() |> Path.join("pre-commit") |> File.exists?()
      System.delete_env("HUSKY_SKIP_INSTALL")
    end

    test "should raise an exception if there is no .git directory" do
      "../../.git"
      |> Path.expand(Util.git_hooks_directory())
      |> File.rm_rf!()

      assert_raise(
        RuntimeError,
        "'#{Path.dirname(Util.git_hooks_directory())}' directory does not exist. Try running $ git init",
        fn ->
          assert "... running 'husky.install' task\n" == capture_io(&Install.run/0)
        end
      )
    end
  end
end
