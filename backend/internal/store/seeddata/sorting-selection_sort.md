选择排序（selection sort）的工作原理非常简单：开启一个循环，每轮从未排序区间选择最小的元素，将其放到已排序区间的末尾。

设数组的长度为 $n$ ，选择排序的算法流程如下图所示。

1. 初始状态下，所有元素未排序，即未排序（索引）区间为 $[0, n-1]$ 。
2. 选取区间 $[0, n-1]$ 中的最小元素，将其与索引 $0$ 处的元素交换。完成后，数组前 1 个元素已排序。
3. 选取区间 $[1, n-1]$ 中的最小元素，将其与索引 $1$ 处的元素交换。完成后，数组前 2 个元素已排序。
4. 以此类推。经过 $n - 1$ 轮选择与交换后，数组前 $n - 1$ 个元素已排序。
5. 仅剩的一个元素必定是最大元素，无须排序，因此数组排序完成。


![选择排序步骤](images/hello-algo/sorting/selection_sort_step1.png)

![selection_sort_step2](images/hello-algo/sorting/selection_sort_step2.png)

![selection_sort_step3](images/hello-algo/sorting/selection_sort_step3.png)

![selection_sort_step4](images/hello-algo/sorting/selection_sort_step4.png)

![selection_sort_step5](images/hello-algo/sorting/selection_sort_step5.png)

![selection_sort_step6](images/hello-algo/sorting/selection_sort_step6.png)

![selection_sort_step7](images/hello-algo/sorting/selection_sort_step7.png)

![selection_sort_step8](images/hello-algo/sorting/selection_sort_step8.png)

![selection_sort_step9](images/hello-algo/sorting/selection_sort_step9.png)

![selection_sort_step10](images/hello-algo/sorting/selection_sort_step10.png)

![selection_sort_step11](images/hello-algo/sorting/selection_sort_step11.png)

在代码中，我们用 $k$ 来记录未排序区间内的最小元素：


**Python**

```python
def selection_sort(nums: list[int]):
    """选择排序"""
    n = len(nums)
    # 外循环：未排序区间为 [i, n-1]
    for i in range(n - 1):
        # 内循环：找到未排序区间内的最小元素
        k = i
        for j in range(i + 1, n):
            if nums[j] < nums[k]:
                k = j  # 记录最小元素的索引
        # 将该最小元素与未排序区间的首个元素交换
        nums[i], nums[k] = nums[k], nums[i]
```


**Go**

```go
/* 选择排序 */
func selectionSort(nums []int) {
	n := len(nums)
	// 外循环：未排序区间为 [i, n-1]
	for i := 0; i < n-1; i++ {
		// 内循环：找到未排序区间内的最小元素
		k := i
		for j := i + 1; j < n; j++ {
			if nums[j] < nums[k] {
				// 记录最小元素的索引
				k = j
			}
		}
		// 将该最小元素与未排序区间的首个元素交换
		nums[i], nums[k] = nums[k], nums[i]

	}
}
```


## 算法特性

- **时间复杂度为 $O(n^2)$、非自适应排序**：外循环共 $n - 1$ 轮，第一轮内循环执行 $n - 1$ 次，最后一轮执行 $1$ 次，即各轮内循环分别执行 $n - 1$、$n - 2$、$\dots$、$2$、$1$ 次，求和为 $\frac{n(n - 1)}{2}$ 。
- **空间复杂度为 $O(1)$、原地排序**：指针 $i$ 和 $j$ 使用常数大小的额外空间。
- **非稳定排序**：如下图所示，元素 `nums[i]` 有可能被交换至与其相等的元素的右边，导致两者的相对顺序发生改变。

![选择排序非稳定示例](images/hello-algo/sorting/selection_sort_instability.png)

> 本文来自 [Hello 算法](https://www.hello-algo.com/)，作者 krahets，采用 CC BY-NC-SA 4.0 授权转载。
