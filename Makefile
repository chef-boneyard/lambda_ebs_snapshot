all: ebs-snapshot-janitor.zip schedule-ebs-snapshot-backups.zip

%.zip: %.py
	zip $@ $<

clean:
	rm *.zip
