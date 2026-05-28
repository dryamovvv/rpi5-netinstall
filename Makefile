.PHONY: all bootstrap install update-offline

all: bootstrap

# One-time: download official boot.img + boot.sig
bootstrap:
	@echo "==> Running bootstrap..."
	@./bootstrap.sh

# Copy config to router's lighttpd
install:
	@echo "==> Run on the router:"
	@echo "  sudo cp lighttpd.conf /etc/lighttpd/lighttpd.conf"
	@echo "  sudo mkdir -p /srv/netinstall/{boot,www,images,scripts}"
	@echo "  sudo cp boot/* /srv/netinstall/boot/"
	@echo "  sudo cp os_list.json /srv/netinstall/www/"
	@echo "  sudo cp scripts/* /srv/netinstall/scripts/"
	@echo "  sudo systemctl restart lighttpd"
	@echo ""
	@echo "==> Don't forget to run bootstrap.sh first!"

# Update os_list.json from latest GitHub release
update:
	@echo "==> Updating os_list.json from GitHub..."
	@./update-os-list.sh
