##
# A semi-compatible DSL for the Bundler Gemfile and Isolate formats.

class Gem::RequestSet::GemDependencyAPI

  java      = Gem::Platform.new 'java'
  mswin     = Gem::Platform.new 'mswin32'
  mingw     = Gem::Platform.new 'x86-mingw32'
  x64_mingw = Gem::Platform.new 'x64-mingw32'

  PLATFORM_MAP = {
    :ruby         => Gem::Platform::RUBY,
    :ruby_18      => Gem::Platform::RUBY,
    :ruby_19      => Gem::Platform::RUBY,
    :ruby_20      => Gem::Platform::RUBY,
    :ruby_21      => Gem::Platform::RUBY,
    :mri          => Gem::Platform::RUBY,
    :mri_18       => Gem::Platform::RUBY,
    :mri_19       => Gem::Platform::RUBY,
    :mri_20       => Gem::Platform::RUBY,
    :mri_21       => Gem::Platform::RUBY,
    :rbx          => Gem::Platform::RUBY,
    :jruby        => java,
    :jruby_18     => java,
    :jruby_19     => java,
    :mswin        => mswin,
    :mingw        => mingw,
    :mingw_18     => mingw,
    :mingw_19     => mingw,
    :mingw_20     => mingw,
    :mingw_21     => mingw,
    :x64_mingw    => x64_mingw,
    :x64_mingw_20 => x64_mingw,
    :x64_mingw_21 => x64_mingw
  }

  PLATFORM_MAP.default_proc = proc do |_, platform|
    raise ArgumentError, "unknown platform #{platform.inspect}"
  end

  gt_eq_0        = Gem::Requirement.new '>= 0'
  tilde_gt_1_8_0 = Gem::Requirement.new '~> 1.8.0'
  tilde_gt_1_9_0 = Gem::Requirement.new '~> 1.9.0'
  tilde_gt_2_0_0 = Gem::Requirement.new '~> 2.0.0'
  tilde_gt_2_1_0 = Gem::Requirement.new '~> 2.1.0'

  VERSION_MAP = { # :nodoc:
    :ruby         => gt_eq_0,
    :ruby_18      => tilde_gt_1_8_0,
    :ruby_19      => tilde_gt_1_9_0,
    :ruby_20      => tilde_gt_2_0_0,
    :ruby_21      => tilde_gt_2_1_0,
    :mri          => gt_eq_0,
    :mri_18       => tilde_gt_1_8_0,
    :mri_19       => tilde_gt_1_9_0,
    :mri_20       => tilde_gt_2_0_0,
    :mri_21       => tilde_gt_2_1_0,
    :rbx          => gt_eq_0,
    :jruby        => gt_eq_0,
    :jruby_18     => tilde_gt_1_8_0,
    :jruby_19     => tilde_gt_1_9_0,
    :mswin        => gt_eq_0,
    :mingw        => gt_eq_0,
    :mingw_18     => tilde_gt_1_8_0,
    :mingw_19     => tilde_gt_1_9_0,
    :mingw_20     => tilde_gt_2_0_0,
    :mingw_21     => tilde_gt_2_1_0,
    :x64_mingw    => gt_eq_0,
    :x64_mingw_20 => tilde_gt_2_0_0,
    :x64_mingw_21 => tilde_gt_2_1_0,
  }

  VERSION_MAP.default_proc = PLATFORM_MAP.default_proc

  ##
  # A Hash containing gem names and files to require from those gems.

  attr_reader :requires

  ##
  # A set of gems that are loaded via the +:path+ option to #gem

  attr_reader :vendor_set # :nodoc:

  ##
  # The groups of gems to exclude from installation

  attr_accessor :without_groups

  ##
  # Creates a new GemDependencyAPI that will add dependencies to the
  # Gem::RequestSet +set+ based on the dependency API description in +path+.

  def initialize set, path
    @set = set
    @path = path

    @current_groups  = nil
    @default_sources = true
    @requires        = Hash.new { |h, name|  h[name]  = [] }
    @vendor_set      = @set.vendor_set
    @without_groups  = []
  end

  ##
  # Loads the gem dependency file

  def load
    instance_eval File.read(@path).untaint, @path, 1
  end

  ##
  # :category: Gem Dependencies DSL
  # :call-seq:
  #   gem(name)
  #   gem(name, *requirements)
  #   gem(name, *requirements, options)
  #
  # Specifies a gem dependency with the given +name+ and +requirements+.  You
  # may also supply +options+ following the +requirements+

  def gem name, *requirements
    options = requirements.pop if requirements.last.kind_of?(Hash)
    options ||= {}

    gem_path name, options

    return unless gem_platforms options

    groups = gem_group name, options

    return unless (groups & @without_groups).empty?

    gem_requires name, options

    @set.gem name, *requirements
  end

  ##
  # Handles the :group and :groups +options+ for the gem with the given
  # +name+.

  def gem_group name, options # :nodoc:
    g = options.delete :group
    all_groups  = g ? Array(g) : []

    groups = options.delete :groups
    all_groups |= groups if groups

    all_groups |= @current_groups if @current_groups

    all_groups
  end

  private :gem_group

  ##
  # Handles the path: option from +options+ for gem +name+.

  def gem_path name, options # :nodoc:
    if directory = options.delete(:path) then
      @vendor_set.add_vendor_gem name, directory
    end
  end

  private :gem_path

  ##
  # Handles the platforms: option from +options+.  Returns true if the
  # platform matches the current platform.

  def gem_platforms options # :nodoc:
    return true unless platform_names = options.delete(:platforms)

    Array(platform_names).any? do |platform_name|
      next false unless Gem::Platform.match PLATFORM_MAP[platform_name]

      VERSION_MAP[platform_name].satisfied_by? Gem.ruby_version
    end
  end

  private :gem_platforms

  ##
  # Handles the require: option from +options+ and adds those files, or the
  # default file to the require list for +name+.

  def gem_requires name, options # :nodoc:
    if options.include? :require then
      if requires = options.delete(:require) then
        @requires[name].concat requires
      end
    else
      @requires[name] << name
    end
  end

  private :gem_requires

  ##
  # Returns the basename of the file the dependencies were loaded from

  def gem_deps_file # :nodoc:
    File.basename @path
  end

  ##
  # :category: Gem Dependencies DSL
  # Block form for placing a dependency in the given +groups+.

  def group *groups
    @current_groups = groups

    yield

  ensure
    @current_groups = nil
  end

  ##
  # :category: Gem Dependencies DSL

  def platform what
    if what == :ruby
      yield
    end
  end

  ##
  # :category: Gem Dependencies DSL

  alias :platforms :platform

  ##
  # :category: Gem Dependencies DSL
  # Restricts this gem dependencies file to the given ruby +version+.  The
  # +:engine+ options from Bundler are currently ignored.

  def ruby version, options = {}
    engine         = options[:engine]
    engine_version = options[:engine_version]

    raise ArgumentError,
          'you must specify engine_version along with the ruby engine' if
            engine and not engine_version

    unless RUBY_VERSION == version then
      message = "Your Ruby version is #{RUBY_VERSION}, " +
                "but your #{gem_deps_file} requires #{version}"

      raise Gem::RubyVersionMismatch, message
    end

    if engine and engine != RUBY_ENGINE then
      message = "Your ruby engine is #{RUBY_ENGINE}, " +
                "but your #{gem_deps_file} requires #{engine}"

      raise Gem::RubyVersionMismatch, message
    end

    if engine_version then
      my_engine_version = Object.const_get "#{RUBY_ENGINE.upcase}_VERSION"

      if engine_version != my_engine_version then
        message =
          "Your ruby engine version is #{RUBY_ENGINE} #{my_engine_version}, " +
          "but your #{gem_deps_file} requires #{engine} #{engine_version}"

        raise Gem::RubyVersionMismatch, message
      end
    end

    return true
  end

  ##
  # :category: Gem Dependencies DSL
  #
  # Sets +url+ as a source for gems for this dependency API.

  def source url
    Gem.sources.clear if @default_sources

    @default_sources = false

    Gem.sources << url
  end

  # TODO: remove this typo name at RubyGems 3.0

  Gem::RequestSet::DepedencyAPI = self # :nodoc:

end

