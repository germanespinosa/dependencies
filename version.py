class Version:
	def __init__(self, major=0, minor=0, build=0):
		self.major = major
		self.minor = minor
		self.build = build

	def __str__(self):
		return str(self.major) + "." + str(self.minor) + "." + '{:0>3}'.format(self.build)


def version():
