exports.defineAutoTests = function() {
    describe('awesome tests', function() {
        it('do something sync', function() {
        expect(1).toBe(1);
        });

        it('do something async', function(done) {
        setTimeout(function() {
            expect(1).toBe(1);
            done();
        }, 100);
        });
    });
};