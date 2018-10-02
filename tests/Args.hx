package;

abstract Args(Array<String>) from Array<String> to Array<String> {
	@:from
	public static function fromString(v:String):Args
		return v.split(' ');
}