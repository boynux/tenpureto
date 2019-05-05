class Redis < FPM::Cookery::Recipe
    name     'tenpureto'
    source   'file:/code'
    version  lookup('version')
    vendor   ENV['VENDOR']

    homepage lookup('homepage')
    description lookup('synopsis')
    maintainer "#{lookup('author')} <#{lookup('email')}>"

    build_depends 'libicu-devel'

    depends 'libicu'

    def bash_completion
      etc/'bash_completion.d'
    end

    def zsh_completion
      share/'zsh/site-functions'
    end

    def build
      sh 'stack', 'build'
    end

    def install
      sh 'stack', 'install', "--local-bin-path", "#{bin}"
      bash_completion.mkpath
      zsh_completion.mkpath
      system "sh", "-c", "#{bin}/tenpureto --bash-completion-script /usr/bin/tenpureto >#{bash_completion}/tenpureto"
      system "sh", "-c", "#{bin}/tenpureto --zsh-completion-script /usr/bin/tenpureto >#{zsh_completion}/_tenpureto"
    end
  end
