require "spec_helper"

describe ".bundle/config" do
  before :each do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack", "1.0.0"
    G
  end

  describe "BUNDLE_APP_CONFIG" do
    it "can be moved with an environment variable" do
      ENV["BUNDLE_APP_CONFIG"] = tmp("foo/bar").to_s
      bundle "install --path vendor/bundle"

      expect(bundled_app(".bundle")).not_to exist
      expect(tmp("foo/bar/config")).to exist
      should_be_installed "rack 1.0.0"
    end

    it "can provide a relative path with the environment variable" do
      FileUtils.mkdir_p bundled_app("omg")
      Dir.chdir bundled_app("omg")

      ENV["BUNDLE_APP_CONFIG"] = "../foo"
      bundle "install --path vendor/bundle"

      expect(bundled_app(".bundle")).not_to exist
      expect(bundled_app("../foo/config")).to exist
      should_be_installed "rack 1.0.0"
    end

    it "removes environment.rb from BUNDLE_APP_CONFIG's path" do
      FileUtils.mkdir_p(tmp("foo/bar"))
      ENV["BUNDLE_APP_CONFIG"] = tmp("foo/bar").to_s
      bundle "install"
      FileUtils.touch tmp("foo/bar/environment.rb")
      should_be_installed "rack 1.0.0"
      expect(tmp("foo/bar/environment.rb")).not_to exist
    end
  end

  describe "global" do
    before(:each) { bundle :install }

    it "is the default" do
      bundle "config foo global"
      run "puts Bundler.settings[:foo]"
      expect(out).to eq("global")
    end

    it "can also be set explicitly" do
      bundle "config --global foo global"
      run "puts Bundler.settings[:foo]"
      expect(out).to eq("global")
    end

    it "has lower precedence than local" do
      bundle "config --local  foo local"

      bundle "config --global foo global"
      expect(out).to match(/Your application has set foo to "local"/)

      run "puts Bundler.settings[:foo]"
      expect(out).to eq("local")
    end

    it "has lower precedence than env" do
      begin
        ENV["BUNDLE_FOO"] = "env"

        bundle "config --global foo global"
        expect(out).to match(/You have a bundler environment variable for foo set to "env"/)

        run "puts Bundler.settings[:foo]"
        expect(out).to eq("env")
      ensure
        ENV.delete("BUNDLE_FOO")
      end
    end

    it "can be deleted" do
      bundle "config --global foo global"
      bundle "config --delete foo"

      run "puts Bundler.settings[:foo] == nil"
      expect(out).to eq("true")
    end

    it "warns when overriding" do
      bundle "config --global foo previous"
      bundle "config --global foo global"
      expect(out).to match(/You are replacing the current global value of foo/)

      run "puts Bundler.settings[:foo]"
      expect(out).to eq("global")
    end

    it "does not warn when using the same value twice" do
      bundle "config --global foo value"
      bundle "config --global foo value"
      expect(out).not_to match(/You are replacing the current global value of foo/)

      run "puts Bundler.settings[:foo]"
      expect(out).to eq("value")
    end

    it "expands the path at time of setting" do
      bundle "config --global local.foo .."
      run "puts Bundler.settings['local.foo']"
      expect(out).to eq(File.expand_path(Dir.pwd + "/.."))
    end
  end

  describe "local" do
    before(:each) { bundle :install }

    it "can also be set explicitly" do
      bundle "config --local foo local"
      run "puts Bundler.settings[:foo]"
      expect(out).to eq("local")
    end

    it "has higher precedence than env" do
      begin
        ENV["BUNDLE_FOO"] = "env"
        bundle "config --local foo local"

        run "puts Bundler.settings[:foo]"
        expect(out).to eq("local")
      ensure
        ENV.delete("BUNDLE_FOO")
      end
    end

    it "can be deleted" do
      bundle "config --local foo local"
      bundle "config --delete foo"

      run "puts Bundler.settings[:foo] == nil"
      expect(out).to eq("true")
    end

    it "warns when overriding" do
      bundle "config --local foo previous"
      bundle "config --local foo local"
      expect(out).to match(/You are replacing the current local value of foo/)

      run "puts Bundler.settings[:foo]"
      expect(out).to eq("local")
    end

    it "expands the path at time of setting" do
      bundle "config --local local.foo .."
      run "puts Bundler.settings['local.foo']"
      expect(out).to eq(File.expand_path(Dir.pwd + "/.."))
    end
  end

  describe "env" do
    before(:each) { bundle :install }

    it "can set boolean properties via the environment" do
      ENV["BUNDLE_FROZEN"] = "true"

      run "if Bundler.settings[:frozen]; puts 'true' else puts 'false' end"
      expect(out).to eq("true")
    end

    it "can set negative boolean properties via the environment" do
      run "if Bundler.settings[:frozen]; puts 'true' else puts 'false' end"
      expect(out).to eq("false")

      ENV["BUNDLE_FROZEN"] = "false"

      run "if Bundler.settings[:frozen]; puts 'true' else puts 'false' end"
      expect(out).to eq("false")

      ENV["BUNDLE_FROZEN"] = "0"

      run "if Bundler.settings[:frozen]; puts 'true' else puts 'false' end"
      expect(out).to eq("false")

      ENV["BUNDLE_FROZEN"] = ""

      run "if Bundler.settings[:frozen]; puts 'true' else puts 'false' end"
      expect(out).to eq("false")
    end

    it "can set properties with periods via the environment" do
      ENV["BUNDLE_FOO__BAR"] = "baz"

      run "puts Bundler.settings['foo.bar']"
      expect(out).to eq("baz")
    end
  end

  describe "gem mirrors" do
    before(:each) { bundle :install }

    it "configures mirrors using keys with `mirror.`" do
      bundle "config --local mirror.http://gems.example.org http://gem-mirror.example.org"
      run(<<-E)
Bundler.settings.gem_mirrors.each do |k, v|
  puts "\#{k} => \#{v}"
end
E
      expect(out).to eq("http://gems.example.org/ => http://gem-mirror.example.org/")
    end
  end

  describe "quoting" do
    before(:each) { gemfile "# no gems" }
    let(:long_string) do
      "--with-xml2-include=/usr/pkg/include/libxml2 --with-xml2-lib=/usr/pkg/lib " \
      "--with-xslt-dir=/usr/pkg"
    end

    it "saves quotes" do
      bundle "config foo something\\'"
      run "puts Bundler.settings[:foo]"
      expect(out).to eq("something'")
    end

    it "doesn't return quotes around values", :ruby => "1.9" do
      bundle "config foo '1'"
      run "puts Bundler.settings.send(:global_config_file).read"
      expect(out).to include("'1'")
      run "puts Bundler.settings[:foo]"
      expect(out).to eq("1")
    end

    it "doesn't duplicate quotes around values", :if => (RUBY_VERSION >= "2.1") do
      bundled_app(".bundle").mkpath
      File.open(bundled_app(".bundle/config"), "w") do |f|
        f.write 'BUNDLE_FOO: "$BUILD_DIR"'
      end

      bundle "config bar baz"
      run "puts Bundler.settings.send(:local_config_file).read"

      # Starting in Ruby 2.1, YAML automatically adds double quotes
      # around some values, including $ and newlines.
      expect(out).to include('BUNDLE_FOO: "$BUILD_DIR"')
    end

    it "doesn't duplicate quotes around long wrapped values" do
      bundle "config foo #{long_string}"

      run "puts Bundler.settings[:foo]"
      expect(out).to eq(long_string)

      bundle "config bar baz"

      run "puts Bundler.settings[:foo]"
      expect(out).to eq(long_string)
    end
  end

  describe "very long lines" do
    before(:each) { bundle :install }

    let(:long_string) do
      "--with-xml2-include=/usr/pkg/include/libxml2 --with-xml2-lib=/usr/pkg/lib " \
      "--with-xslt-dir=/usr/pkg"
    end

    let(:long_string_without_special_characters) do
      "here is quite a long string that will wrap to a second line but will not be " \
      "surrounded by quotes"
    end

    it "doesn't wrap values" do
      bundle "config foo #{long_string}"
      run "puts Bundler.settings[:foo]"
      expect(out).to match(long_string)
    end

    it "can read wrapped unquoted values" do
      bundle "config foo #{long_string_without_special_characters}"
      run "puts Bundler.settings[:foo]"
      expect(out).to match(long_string_without_special_characters)
    end
  end
end

describe "setting gemfile via config" do
  context "when only the non-default Gemfile exists" do
    it "persists the gemfile location to .bundle/config" do
      File.open(bundled_app("NotGemfile"), "w") do |f|
        f.write <<-G
          source "file://#{gem_repo1}"
          gem 'rack'
        G
      end

      bundle "config --local gemfile #{bundled_app("NotGemfile")}"
      expect(File.exist?(".bundle/config")).to eq(true)

      bundle "config"
      expect(out).to include("NotGemfile")
    end
  end
end
