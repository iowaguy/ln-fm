modeldir := models
.PHONY: clean verifynormal

interactive:
	spin -i $(modeldir)/normal-operation.pml

clean:
	rm -f pan pan.* *.trail _spin_nvr.tmp model.tmp.pml
