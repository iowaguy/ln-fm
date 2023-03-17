
modeldir := models
.PHONY: clean verifynormal

verifynormal: | $(modeldir)
	rm -f normal-operation.pml.trail
	spin -a -run -DNP -l $(modeldir)/normal-operation.pml
	rm -f pan

replayshort:
	spin -c -k normal-operation.pml.trail $(modeldir)/normal-operation.pml

replayverbose:
	spin -t0 -w -s -r -c -k normal-operation.pml.trail -p $(modeldir)/normal-operation.pml

interactive:
	spin -i $(modeldir)/normal-operation.pml

shorten50:
	spin -a $(modeldir)/normal-operation.pml
	cc -DREACH -o pan pan.c
	./pan -i -m50

shorten100:
	spin -a $(modeldir)/normal-operation.pml
	cc -DREACH -o pan pan.c
	./pan -i -m100
