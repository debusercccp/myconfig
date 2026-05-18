# Edit this configuration file to define what should be installed on 
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "lynx"; # Define your hostname.
  
  # Opzionale ma consigliato per applicazioni Electron/Ozone su Wayland
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Rome";

  # Select internationalisation properties.
  i18n.defaultLocale = "it_IT.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "it_IT.UTF-8";
    LC_IDENTIFICATION = "it_IT.UTF-8";
    LC_MEASUREMENT = "it_IT.UTF-8";
    LC_MONETARY = "it_IT.UTF-8";
    LC_NAME = "it_IT.UTF-8";
    LC_NUMERIC = "it_IT.UTF-8";
    LC_PAPER = "it_IT.UTF-8";
    LC_TELEPHONE = "it_IT.UTF-8";
    LC_TIME = "it_IT.UTF-8";
  };

  fonts.packages = with pkgs; [
	nerd-fonts.shure-tech-mono
	];


  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the Cinnamon Desktop Environment (and LightDM)
  # Note: Niri can be launched directly from LightDM!
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.cinnamon.enable = true;

  # === NIRI & WAYLAND CONFIGURATION ===
  # Enables Niri session, locks, and systemd integration
  programs.niri.enable = true;
  
  # Optional: standard Wayland support tools
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "gb";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "uk";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.noya = {
    isNormalUser = true;
    description = "noya";
    extraGroups = [ "networkmanager" "wheel" "docker" ]; # Note: removed "sudoers" as "wheel" covers it
    packages = with pkgs; [
       thunderbird
    ];
  };

  networking.firewall.allowedTCPPorts = [ 11434 3000 8080 ];

  # Install firefox.
  programs.firefox.enable = true;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    nspr nss glib gtk3 atk at-spi2-atk cairo pango gdk-pixbuf
    xorg.libX11 xorg.libXcomposite xorg.libXdamage xorg.libXext
    xorg.libXfixes xorg.libXi xorg.libXrandr xorg.libXrender
    xorg.libXtst xorg.libXScrnSaver alsa-lib mesa expat dbus
    libdrm libxkbcommon systemd
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    neovim
    wget
    gcc
    kitty
    fastfetch
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
    python311
    python311Packages.pip
    nmap
    htop
    git
    curl
    cargo
    
    kdePackages.qtsvg
    kdePackages.dolphin
    fuzzel          # Wayland application launcher
    dunst           # Notification daemon
    waybar          # Status bar (often paired with Niri)
    wl-clipboard    # Clipboard manager for Wayland
    swaybg          # Wallpaper setter for Wayland
    xwayland        # For running X11 apps inside Niri seamlessly
  ];

  programs.gnupg.agent = {
     enable = true;
     enableSSHSupport = true;
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  system.stateVersion = "25.11";
}
