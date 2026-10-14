"""Algorithm checks on synthetic shapes, not tests of field accuracy."""
import unittest

import cv2
import numpy as np

from probe import compare, extract


class ShapeChecks(unittest.TestCase):
    def image(self, shape, size, angle=0):
        gray = np.full((160, 160), 35, np.uint8)
        if shape == "rectangle":
            points = cv2.boxPoints(((80, 80), size, angle)).astype(np.int32)
            cv2.fillConvexPoly(gray, points, 200)
            cv2.circle(gray, (80, 80), 15, 110, cv2.FILLED)
        else:
            cv2.circle(gray, (80, 80), size, 170, cv2.FILLED)
        return np.repeat(gray[:, :, None], 3, axis=2)

    def test_spatial_features_separate_rectangle_from_circle(self):
        rectangle = extract(self.image("rectangle", (70, 54), 15))
        circle = extract(self.image("circle", 32))
        self.assertEqual(rectangle["quality"], "MEASURED")
        self.assertGreater(rectangle["extent"], circle["extent"] + 0.10)
        self.assertGreater(rectangle["corner_fill"], circle["corner_fill"] + 0.30)

    def test_flat_background_is_not_a_shape(self):
        self.assertEqual(extract(np.full((80, 80, 3), 190, np.uint8))["quality"], "LOW_CONTRAST")

    def test_clipped_body_is_rejected(self):
        image = np.full((80, 80, 3), 35, np.uint8)
        image[10:65, :50] = 200
        self.assertEqual(extract(image)["quality"], "TOUCHES_CROP_BORDER")

    def test_no_match_does_not_become_empty(self):
        prototypes = {"present": [0.95, 0.95, 1.0, 1.3],
                      "empty": [0.78, 0.3, 0.25, 1.0],
                      "sprocket": [0.78, 0.3, 0.55, 1.0]}
        unknown = {"quality": "MEASURED", "extent": 0.3, "corner_fill": 0.1,
                   "relative_size": 2.0, "aspect": 3.0}
        self.assertEqual(compare(unknown, prototypes)["match"], "UNCERTAIN")

    def test_equal_distance_is_uncertain(self):
        prototypes = {"present": [0.9, 0.8, 1.0, 1.2],
                      "empty": [0.9, 0.8, 1.0, 1.2],
                      "sprocket": [0.78, 0.3, 0.55, 1.0]}
        f = {"quality": "MEASURED", "extent": 0.9, "corner_fill": 0.8,
             "relative_size": 1.0, "aspect": 1.2}
        self.assertEqual(compare(f, prototypes)["match"], "UNCERTAIN")


if __name__ == "__main__":
    unittest.main()
