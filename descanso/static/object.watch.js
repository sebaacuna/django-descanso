// Cross-browser object.watch and object.unwatch

// object.watch

if (!Object.prototype.watch) {
	Object.prototype.watch = function (prop, handler) {
		var oldval = this[prop], newval = oldval,
		getter = function () {
			return newval;
		},
		setter = function (val) {
            if(typeof prop=='function') return; //HACK
			oldval = newval;
			return newval = handler.call(this, prop, oldval, val);
		};
		if (delete this[prop]) { // can't watch constants
			if (Object.defineProperty) { // ECMAScript 5
				Object.defineProperty(this, prop, {
					get: getter,
					set: setter,
					enumerable: false,
					configurable: true
				});
			} else if (Object.prototype.__defineGetter__ && Object.prototype.__defineSetter__) { // legacy
				Object.prototype.__defineGetter__.call(this, prop, getter);
				Object.prototype.__defineSetter__.call(this, prop, setter);
			}
		}
	};
}

// object.unwatch
if (!Object.prototype.unwatch) {
	Object.prototype.unwatch = function (prop) {
		var val = this[prop];
		delete this[prop]; // remove accessors
		this[prop] = val;
	};
}