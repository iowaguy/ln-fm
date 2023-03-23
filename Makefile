
modeldir := models
.PHONY: clean verifynormal

verifynormal: clean | $(modeldir)
	spin -a $(modeldir)/normal-operation.pml
	cc -o pan pan.c
	./pan

verifynonprogress: clean
	spin -a $(modeldir)/normal-operation.pml
	cc -DNP -o pan pan.c
	./pan -l

replayshort:
	spin -c -k normal-operation.pml.trail $(modeldir)/normal-operation.pml

replayverbose:
	spin -t0 -w -s -r -c -k normal-operation.pml.trail -p $(modeldir)/normal-operation.pml

interactive:
	spin -i $(modeldir)/normal-operation.pml

shortenviolation50:
	spin -a $(modeldir)/normal-operation.pml
	cc -DREACH -o pan pan.c
	./pan -i -m50

shortenviolation100:
	spin -a $(modeldir)/normal-operation.pml
	cc -DREACH -o pan pan.c
	./pan -i -m100

clean:
	rm -f pan pan.* *.trail _spin_nvr.tmp model.tmp.pml
