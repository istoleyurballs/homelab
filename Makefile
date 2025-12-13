.PHONY: help
help:
	@echo "Available commands:"
	@echo "  - make up"
	@echo "  - make down"

.PHONY: up
up:
	kubectl apply -k charts
	kubectl apply -k cert-manager-issuers
	kubectl apply -k redirects
	kubectl apply -k auth
	kubectl apply -k monitoring
	kubectl apply -k mealie
	kubectl apply -k jellyfin
	kubectl apply -k paperless
	kubectl apply -k immich
	kubectl apply -k silverbullet

.PHONY: down
down:
	@echo "Really ???"

.PHONY: down-like-for-real-i-know-what-i-am-doing
down-like-for-real-i-know-what-i-am-doing:
	@echo "Know you this will delete like everything ?"

.PHONY: down-like-for-real-i-know-what-i-am-doing-not-a-type
down-like-for-real-i-know-what-i-am-doing-not-a-type:
	kubectl delete -k silverbullet --interactive
	kubectl delete -k immich --interactive
	kubectl delete -k paperless --interactive
	kubectl delete -k jellyfin --interactive
	kubectl delete -k mealie --interactive
	kubectl delete -k monitoring --interactive
	kubectl delete -k auth --interactive
	kubectl delete -k redirects --interactive
	kubectl delete -k cert-manager-issuers --interactive
	kubectl delete -k charts --interactive
